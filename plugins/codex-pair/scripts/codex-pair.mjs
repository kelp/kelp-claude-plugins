#!/usr/bin/env node
// codex-pair: manage persistent Codex pairing threads.
//
// Wraps `codex exec` / `codex exec resume` and pins one Codex
// thread per pair label so a Claude Code session can hold a
// long-lived conversation with the same Codex partner. State
// lives in ~/.claude/codex-pair/pairs.json (override with
// CODEX_PAIR_STATE_FILE).
//
//   start [--label L] [--cwd D] [--model M] [--sandbox S]
//         prompt on stdin; creates the pair thread
//   send  [--label L]           prompt on stdin; continues it
//   list                        print state
//   end   [--label L]           forget the pair (thread remains
//                               on disk; `codex resume <id>` works)

import { spawn } from "node:child_process";
import {
  mkdirSync,
  readFileSync,
  renameSync,
  rmdirSync,
  statSync,
  writeFileSync
} from "node:fs";
import { homedir } from "node:os";
import path from "node:path";
import {
  parseCliArgs,
  parseEvents,
  getPair,
  upsertPair,
  removePair,
  applySendUpdate,
  claimInFlight,
  releaseInFlight,
  isInFlight,
  buildStartArgs,
  buildSendArgs,
  renderEventLine
} from "./lib.mjs";

const STATE_FILE =
  process.env.CODEX_PAIR_STATE_FILE ??
  path.join(homedir(), ".claude", "codex-pair", "pairs.json");

// Only a missing file means empty state. A corrupt or misshapen
// file is an error: silently treating it as empty would let the
// next `start` overwrite real pinned-thread mappings.
function loadState() {
  let text;
  try {
    text = readFileSync(STATE_FILE, "utf8");
  } catch (err) {
    if (err.code === "ENOENT") return { pairs: [] };
    throw new Error(`cannot read ${STATE_FILE}: ${err.message}`);
  }
  let state;
  try {
    state = JSON.parse(text);
  } catch {
    throw new Error(
      `${STATE_FILE} is corrupt; fix or remove it (threads survive: ` +
        "`codex resume <id>` still works)"
    );
  }
  if (!state || !Array.isArray(state.pairs)) {
    throw new Error(`${STATE_FILE} has invalid shape: pairs must be an array`);
  }
  for (const p of state.pairs) {
    if (
      typeof p?.label !== "string" ||
      typeof p?.threadId !== "string" ||
      typeof p?.cwd !== "string" ||
      typeof p?.turns !== "number"
    ) {
      throw new Error(
        `${STATE_FILE} has invalid shape: each pair needs ` +
          "label, threadId, cwd, turns"
      );
    }
  }
  return state;
}

const LOCK_DIR = STATE_FILE + ".lock";
const LOCK_TIMEOUT_MS = Number(
  process.env.CODEX_PAIR_LOCK_TIMEOUT_MS ?? 10_000
);
const LOCK_STALE_MS = 60_000;

const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

async function acquireLock() {
  mkdirSync(path.dirname(STATE_FILE), { recursive: true });
  const deadline = Date.now() + LOCK_TIMEOUT_MS;
  for (;;) {
    try {
      mkdirSync(LOCK_DIR);
      return;
    } catch (err) {
      if (err.code !== "EEXIST") throw err;
      try {
        if (Date.now() - statSync(LOCK_DIR).mtimeMs > LOCK_STALE_MS) {
          rmdirSync(LOCK_DIR);
          continue;
        }
      } catch {
        continue; // lock vanished between checks; retry
      }
      if (Date.now() > deadline) {
        throw new Error(
          `timed out waiting for ${LOCK_DIR}; remove it if no other ` +
            "codex-pair command is running"
        );
      }
      await sleep(25);
    }
  }
}

function releaseLock() {
  try {
    rmdirSync(LOCK_DIR);
  } catch {
    // already released
  }
}

// All writes go through here: re-load fresh state under the lock
// so concurrent commands never save a stale snapshot and drop
// each other's labels. `fn` gets fresh state, returns the next
// state.
async function mutateState(fn) {
  await acquireLock();
  try {
    const next = fn(loadState());
    saveState(next);
    return next;
  } finally {
    releaseLock();
  }
}

// Write-to-temp-then-rename so a crash mid-write never leaves a
// truncated state file. Callers must hold the state lock (see
// mutateState); saveState alone does not serialize writers.
function saveState(state) {
  mkdirSync(path.dirname(STATE_FILE), { recursive: true });
  const tmp = `${STATE_FILE}.tmp.${process.pid}`;
  writeFileSync(tmp, JSON.stringify(state, null, 2) + "\n");
  renameSync(tmp, STATE_FILE);
}

function readStdin() {
  return new Promise((resolve) => {
    const chunks = [];
    process.stdin.on("data", (c) => chunks.push(c));
    process.stdin.on("end", () => resolve(Buffer.concat(chunks).toString()));
    process.stdin.on("error", () => resolve(""));
  });
}

// codex is a Node launcher that spawns the native binary, so on
// timeout we must terminate the whole process group, and we must
// not settle (or release the in-flight token) until the tree is
// dead: an orphaned native process would keep appending to the
// thread's rollout file. detached:true gives the child its own
// group; SIGTERM first, SIGKILL after a grace period; reject
// only on close. External SIGTERM/SIGINT forward to the group.
const KILL_GRACE_MS = 5000;

function runCodex(args, { cwd, prompt, timeoutSec }) {
  return new Promise((resolve, reject) => {
    const child = spawn("codex", args, {
      cwd: cwd ?? process.cwd(),
      stdio: ["pipe", "pipe", "inherit"],
      detached: true
    });
    const killGroup = (sig) => {
      try {
        process.kill(-child.pid, sig);
      } catch {
        // group already gone
      }
    };
    let timedOut = false;
    let externallyTerminated = false;
    let escalation;
    const terminate = () => {
      killGroup("SIGTERM");
      if (!escalation) {
        escalation = setTimeout(() => killGroup("SIGKILL"), KILL_GRACE_MS);
        escalation.unref();
      }
    };
    const timer = setTimeout(() => {
      timedOut = true;
      terminate();
    }, timeoutSec * 1000);
    // A child may trap SIGTERM and exit 0; cancellation must still
    // reject so a cancelled turn is never recorded as success.
    const onSignal = () => {
      externallyTerminated = true;
      terminate();
    };
    process.on("SIGTERM", onSignal);
    process.on("SIGINT", onSignal);
    const cleanup = () => {
      clearTimeout(timer);
      clearTimeout(escalation);
      process.off("SIGTERM", onSignal);
      process.off("SIGINT", onSignal);
    };
    let stdout = "";
    let lineBuf = "";
    child.stdout.on("data", (c) => {
      stdout += c;
      lineBuf += c;
      let i;
      while ((i = lineBuf.indexOf("\n")) >= 0) {
        const line = lineBuf.slice(0, i);
        lineBuf = lineBuf.slice(i + 1);
        try {
          const rendered = renderEventLine(JSON.parse(line));
          if (rendered) process.stderr.write(`[codex] ${rendered}\n`);
        } catch {
          // non-JSON line; skip
        }
      }
    });
    child.on("error", (err) => {
      cleanup();
      reject(err);
    });
    child.on("close", (code, signal) => {
      cleanup();
      if (timedOut) {
        reject(
          new Error(
            `codex timed out after ${timeoutSec}s; process group terminated`
          )
        );
      } else if (externallyTerminated) {
        reject(new Error("codex terminated by external signal"));
      } else if (code !== 0) {
        reject(
          new Error(
            `codex exited with ${signal ? `signal ${signal}` : `code ${code}`}`
          )
        );
      } else {
        resolve(stdout);
      }
    });
    child.stdin.end(prompt);
  });
}

function output(value) {
  process.stdout.write(JSON.stringify(value, null, 2) + "\n");
}

async function main() {
  // Tree termination uses POSIX process groups (kill(-pid));
  // Windows would catch neither signal and leak the native
  // codex process past token release. Fail fast instead.
  if (process.platform === "win32") {
    throw new Error(
      "codex-pair supports macOS and Linux only (POSIX process-group " +
        "termination)"
    );
  }
  const opts = parseCliArgs(process.argv.slice(2));
  const state = loadState();

  if (opts.command === "list") {
    output(state);
    return;
  }

  if (opts.command === "end") {
    let removed;
    await mutateState((s) => {
      removed = getPair(s, opts.label);
      if (removed && isInFlight(removed, Date.now())) {
        throw new Error(
          `an operation is in flight for '${opts.label}'; ` +
            "wait for it before ending the pair"
        );
      }
      return removePair(s, opts.label);
    });
    output({ removed: removed ?? opts.label });
    return;
  }

  const prompt = await readStdin();
  if (!prompt.trim()) {
    throw new Error(`${opts.command} requires a prompt on stdin`);
  }

  if (opts.command === "start") {
    if (getPair(state, opts.label)) {
      throw new Error(
        `pair '${opts.label}' already exists; use send, or end it first`
      );
    }
    const cwd = opts.cwd ?? process.cwd();
    const stdout = await runCodex(buildStartArgs(opts), {
      cwd,
      prompt,
      timeoutSec: opts.timeoutSec
    });
    const events = parseEvents(stdout);
    if (!events.threadId) {
      throw new Error(
        `codex returned no thread id; errors: ${events.errors.join("; ")}`
      );
    }
    const now = new Date().toISOString();
    await mutateState((s) => {
      if (getPair(s, opts.label)) {
        throw new Error(
          `pair '${opts.label}' was created concurrently; ` +
            `orphaned thread: codex resume ${events.threadId}`
        );
      }
      return upsertPair(s, {
        label: opts.label,
        threadId: events.threadId,
        cwd,
        model: opts.model,
        sandbox: opts.sandbox,
        createdAt: now,
        lastUsedAt: now,
        turns: 1
      });
    });
    output({
      label: opts.label,
      threadId: events.threadId,
      lastMessage: events.lastMessage,
      errors: events.errors
    });
    return;
  }

  // send: claim the label's in-flight token before touching the
  // codex thread, so overlapping sends fail fast instead of
  // interleaving appends into one rollout file.
  const expiresAt = new Date(
    Date.now() + (opts.timeoutSec + 60) * 1000
  ).toISOString();
  let pair;
  await mutateState((s) => {
    const claimed = claimInFlight(
      s,
      opts.label,
      { pid: process.pid, expiresAt },
      Date.now()
    );
    pair = getPair(claimed, opts.label);
    return claimed;
  });

  let events;
  try {
    const stdout = await runCodex(buildSendArgs(pair.threadId, opts), {
      cwd: pair.cwd,
      prompt,
      timeoutSec: opts.timeoutSec
    });
    events = parseEvents(stdout);
    await mutateState((s) =>
      applySendUpdate(s, pair.label, pair.threadId, new Date().toISOString())
    );
  } finally {
    await mutateState((s) =>
      releaseInFlight(s, opts.label, process.pid)
    );
  }
  output({
    label: pair.label,
    threadId: pair.threadId,
    lastMessage: events.lastMessage,
    errors: events.errors
  });
}

main().catch((err) => {
  process.stderr.write(`codex-pair: ${err.message}\n`);
  process.exit(1);
});
