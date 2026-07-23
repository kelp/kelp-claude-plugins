// Pure logic for the codex-pair CLI. No I/O here; everything in
// this module is unit-tested by tests/lib.test.mjs.

const COMMANDS = new Set(["start", "send", "list", "end"]);

// codex 0.145 rejects danger-full-access only behind an extra flag;
// a pair partner never needs it, so we refuse it outright.
const SANDBOXES = new Set(["read-only", "workspace-write"]);

export function parseCliArgs(argv) {
  if (argv.length === 0) {
    throw new Error(
      "usage: codex-pair.mjs <start|send|list|end> [--label L] " +
        "[--cwd D] [--model M] [--sandbox S] [--timeout-sec N]"
    );
  }
  const [command, ...rest] = argv;
  if (!COMMANDS.has(command)) {
    throw new Error(`unknown command: ${command}`);
  }
  const opts = {
    command,
    label: "default",
    cwd: null,
    model: null,
    sandbox: "read-only",
    timeoutSec: 600
  };
  const known = new Set([
    "--label", "--cwd", "--model", "--sandbox", "--timeout-sec"
  ]);
  for (let i = 0; i < rest.length; i += 2) {
    const flag = rest[i];
    const value = rest[i + 1];
    if (!known.has(flag)) {
      throw new Error(`unknown flag: ${flag}`);
    }
    if (value === undefined) {
      throw new Error(`missing value for ${flag}`);
    }
    switch (flag) {
      case "--label":
        opts.label = value;
        break;
      case "--cwd":
        opts.cwd = value;
        break;
      case "--model":
        opts.model = value;
        break;
      case "--sandbox":
        if (!SANDBOXES.has(value)) {
          throw new Error(
            `sandbox must be one of: ${[...SANDBOXES].join(", ")}`
          );
        }
        opts.sandbox = value;
        break;
      case "--timeout-sec":
        opts.timeoutSec = Number(value);
        if (!Number.isFinite(opts.timeoutSec) || opts.timeoutSec <= 0) {
          throw new Error("--timeout-sec must be a positive number");
        }
        break;
    }
  }
  return opts;
}

// Parse `codex exec --json` JSONL events. Returns the thread id,
// the last agent message, and any error events.
export function parseEvents(text) {
  const result = { threadId: null, lastMessage: null, errors: [] };
  for (const line of text.split("\n")) {
    const trimmed = line.trim();
    if (!trimmed) continue;
    let event;
    try {
      event = JSON.parse(trimmed);
    } catch {
      continue;
    }
    if (event.type === "thread.started" && event.thread_id) {
      result.threadId = event.thread_id;
    } else if (
      event.type === "item.completed" &&
      event.item?.type === "agent_message"
    ) {
      result.lastMessage = event.item.text;
    } else if (event.type === "error") {
      result.errors.push(event.message ?? JSON.stringify(event));
    }
  }
  return result;
}

export function getPair(state, label) {
  return state.pairs.find((p) => p.label === label);
}

export function upsertPair(state, pair) {
  const pairs = state.pairs.filter((p) => p.label !== pair.label);
  pairs.push(pair);
  return { ...state, pairs };
}

export function removePair(state, label) {
  if (!getPair(state, label)) {
    const labels = state.pairs.map((p) => p.label).join(", ") || "none";
    throw new Error(`no pair named '${label}' (have: ${labels})`);
  }
  return { ...state, pairs: state.pairs.filter((p) => p.label !== label) };
}

export function buildStartArgs({ sandbox, model }) {
  const args = ["exec", "--json", "--skip-git-repo-check", "-s", sandbox];
  if (model) args.push("-m", model);
  args.push("-");
  return args;
}

// `codex exec resume` accepts no -s or -C flags (codex 0.145);
// sandbox and working root come from the recorded session. We set
// the child process cwd instead of -C in both commands.
export function buildSendArgs(threadId, { model }) {
  const args = ["exec", "resume", threadId, "--json", "--skip-git-repo-check"];
  if (model) args.push("-m", model);
  args.push("-");
  return args;
}
