import { test } from "node:test";
import assert from "node:assert/strict";
import {
  parseCliArgs,
  parseEvents,
  getPair,
  upsertPair,
  removePair,
  buildStartArgs,
  buildSendArgs
} from "../scripts/lib.mjs";

// --- parseCliArgs ---

test("parseCliArgs applies defaults for start", () => {
  const opts = parseCliArgs(["start"]);
  assert.equal(opts.command, "start");
  assert.equal(opts.label, "default");
  assert.equal(opts.sandbox, "read-only");
  assert.equal(opts.model, null);
  assert.equal(opts.cwd, null);
  assert.equal(opts.timeoutSec, 600);
});

test("parseCliArgs reads flags", () => {
  const opts = parseCliArgs([
    "start", "--label", "auth", "--cwd", "/repo",
    "--model", "gpt-5.5-codex", "--sandbox", "workspace-write",
    "--timeout-sec", "120"
  ]);
  assert.equal(opts.label, "auth");
  assert.equal(opts.cwd, "/repo");
  assert.equal(opts.model, "gpt-5.5-codex");
  assert.equal(opts.sandbox, "workspace-write");
  assert.equal(opts.timeoutSec, 120);
});

test("parseCliArgs rejects unknown command and flags", () => {
  assert.throws(() => parseCliArgs(["dance"]), /unknown command/i);
  assert.throws(() => parseCliArgs(["start", "--bogus"]), /unknown flag/i);
  assert.throws(() => parseCliArgs([]), /usage/i);
});

test("parseCliArgs rejects invalid sandbox", () => {
  assert.throws(
    () => parseCliArgs(["start", "--sandbox", "danger-full-access"]),
    /sandbox/i
  );
});

// --- parseEvents ---

const JSONL = [
  '{"type":"thread.started","thread_id":"t-123"}',
  '{"type":"turn.started"}',
  '{"type":"item.completed","item":{"id":"item_0","type":"agent_message","text":"first"}}',
  '{"type":"item.completed","item":{"id":"item_1","type":"agent_message","text":"final answer"}}',
  '{"type":"turn.completed","usage":{"input_tokens":1}}'
].join("\n");

test("parseEvents extracts thread id and last agent message", () => {
  const r = parseEvents(JSONL);
  assert.equal(r.threadId, "t-123");
  assert.equal(r.lastMessage, "final answer");
  assert.deepEqual(r.errors, []);
});

test("parseEvents handles empty and non-JSON lines", () => {
  const r = parseEvents("\nnot json\n");
  assert.equal(r.threadId, null);
  assert.equal(r.lastMessage, null);
});

test("parseEvents collects error events", () => {
  const r = parseEvents('{"type":"error","message":"rate limited"}');
  assert.deepEqual(r.errors, ["rate limited"]);
});

// --- state ops ---

const pair = (label) => ({
  label,
  threadId: `thread-${label}`,
  cwd: "/repo",
  createdAt: "2026-07-22T00:00:00Z",
  lastUsedAt: "2026-07-22T00:00:00Z",
  turns: 1
});

test("upsertPair adds and getPair finds", () => {
  const s1 = upsertPair({ pairs: [] }, pair("a"));
  assert.equal(getPair(s1, "a").threadId, "thread-a");
  assert.equal(getPair(s1, "missing"), undefined);
});

test("upsertPair replaces same label without duplicating", () => {
  const s1 = upsertPair({ pairs: [] }, pair("a"));
  const s2 = upsertPair(s1, { ...pair("a"), turns: 5 });
  assert.equal(s2.pairs.length, 1);
  assert.equal(getPair(s2, "a").turns, 5);
});

test("removePair removes, throws on missing", () => {
  const s1 = upsertPair({ pairs: [] }, pair("a"));
  const s2 = removePair(s1, "a");
  assert.equal(s2.pairs.length, 0);
  assert.throws(() => removePair(s2, "a"), /no pair/i);
});

// --- codex argv construction ---

test("buildStartArgs uses exec with sandbox and stdin prompt", () => {
  const args = buildStartArgs({ sandbox: "read-only", model: null });
  assert.deepEqual(args, [
    "exec", "--json", "--skip-git-repo-check",
    "-s", "read-only", "-"
  ]);
});

test("buildStartArgs includes model when set", () => {
  const args = buildStartArgs({ sandbox: "read-only", model: "gpt-x" });
  assert.ok(args.includes("-m"));
  assert.ok(args.includes("gpt-x"));
});

// codex 0.145: `exec resume` accepts no -s or -C flags; sandbox and
// cwd come from the recorded session. Passing -s breaks the call.
test("buildSendArgs resumes by id and never passes -s or -C", () => {
  const args = buildSendArgs("t-123", { model: null });
  assert.deepEqual(args, [
    "exec", "resume", "t-123", "--json", "--skip-git-repo-check", "-"
  ]);
  assert.ok(!args.includes("-s"));
  assert.ok(!args.includes("-C"));
});

test("buildSendArgs includes model when set", () => {
  const args = buildSendArgs("t-123", { model: "gpt-x" });
  assert.ok(args.includes("-m"));
  assert.ok(args.includes("gpt-x"));
});
