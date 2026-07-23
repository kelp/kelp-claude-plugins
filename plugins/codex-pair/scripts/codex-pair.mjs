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
import { mkdirSync, readFileSync, writeFileSync } from "node:fs";
import { homedir } from "node:os";
import path from "node:path";
import {
  parseCliArgs,
  parseEvents,
  getPair,
  upsertPair,
  removePair,
  buildStartArgs,
  buildSendArgs
} from "./lib.mjs";

const STATE_FILE =
  process.env.CODEX_PAIR_STATE_FILE ??
  path.join(homedir(), ".claude", "codex-pair", "pairs.json");

function loadState() {
  try {
    return JSON.parse(readFileSync(STATE_FILE, "utf8"));
  } catch {
    return { pairs: [] };
  }
}

function saveState(state) {
  mkdirSync(path.dirname(STATE_FILE), { recursive: true });
  writeFileSync(STATE_FILE, JSON.stringify(state, null, 2) + "\n");
}

function readStdin() {
  return new Promise((resolve) => {
    const chunks = [];
    process.stdin.on("data", (c) => chunks.push(c));
    process.stdin.on("end", () => resolve(Buffer.concat(chunks).toString()));
    process.stdin.on("error", () => resolve(""));
  });
}

function runCodex(args, { cwd, prompt, timeoutSec }) {
  return new Promise((resolve, reject) => {
    const child = spawn("codex", args, {
      cwd: cwd ?? process.cwd(),
      stdio: ["pipe", "pipe", "inherit"]
    });
    const timer = setTimeout(() => {
      child.kill("SIGKILL");
      reject(new Error(`codex timed out after ${timeoutSec}s`));
    }, timeoutSec * 1000);
    let stdout = "";
    child.stdout.on("data", (c) => (stdout += c));
    child.on("error", (err) => {
      clearTimeout(timer);
      reject(err);
    });
    child.on("close", (code) => {
      clearTimeout(timer);
      if (code !== 0) {
        reject(new Error(`codex exited with code ${code}`));
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
  const opts = parseCliArgs(process.argv.slice(2));
  const state = loadState();

  if (opts.command === "list") {
    output(state);
    return;
  }

  if (opts.command === "end") {
    const pair = getPair(state, opts.label);
    saveState(removePair(state, opts.label));
    output({ removed: pair ?? opts.label });
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
    saveState(
      upsertPair(state, {
        label: opts.label,
        threadId: events.threadId,
        cwd,
        model: opts.model,
        sandbox: opts.sandbox,
        createdAt: now,
        lastUsedAt: now,
        turns: 1
      })
    );
    output({
      label: opts.label,
      threadId: events.threadId,
      lastMessage: events.lastMessage,
      errors: events.errors
    });
    return;
  }

  // send
  const pair = getPair(state, opts.label);
  if (!pair) {
    const labels = state.pairs.map((p) => p.label).join(", ") || "none";
    throw new Error(`no pair named '${opts.label}' (have: ${labels})`);
  }
  const stdout = await runCodex(buildSendArgs(pair.threadId, opts), {
    cwd: pair.cwd,
    prompt,
    timeoutSec: opts.timeoutSec
  });
  const events = parseEvents(stdout);
  saveState(
    upsertPair(state, {
      ...pair,
      lastUsedAt: new Date().toISOString(),
      turns: pair.turns + 1
    })
  );
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
