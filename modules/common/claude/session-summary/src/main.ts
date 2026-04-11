#!/usr/bin/env bun
// claude-session-summary: Run the session summary pipeline.
//
// Hook mode:
//   echo '{"session_id":"...","transcript_path":"...","cwd":"..."}' | claude-session-summary --mode hook
//
// Summarize mode (for testing):
//   claude-session-summary --mode summarize --transcript <path> [--session-id <id>] [--project-dir <dir>]
//
// Problem review mode:
//   claude-session-summary --mode problem-review [--project-dir <dir>]
//
// Tool path injected at build time via makeWrapper env var:
//   CLAUDE_BIN  - path to sandboxed claude binary

import { existsSync, readFileSync, statSync } from "fs";
import { join } from "path";
import { runPipeline, info } from "./pipeline.ts";
import { problemReview } from "./problem-review.ts";

const CLAUDE_BIN = process.env.CLAUDE_BIN ?? "claude";

const USAGE = `Usage:
  Hook mode:
    echo '{"session_id":"...","transcript_path":"...","cwd":"..."}' | claude-session-summary --mode hook

  Summarize mode (for testing):
    claude-session-summary --mode summarize --transcript <path> [--session-id <id>] [--project-dir <dir>]

  Problem review mode:
    claude-session-summary --mode problem-review [--project-dir <dir>]

Options:
  --mode <hook|summarize|problem-review>  Execution mode (required)
  --transcript <path>      Path to transcript JSONL file (summarize mode)
  --session-id <id>        Session ID (default: cli-<timestamp>)
  --project-dir <dir>      Project directory (default: cwd)
  --debug                  Print the condensed transcript sent to Claude (stderr)
  --dry-run                Run the full pipeline and print output to stdout instead of writing to disk
  -h, --help               Show this help

Exit codes:
  0  success (or no-op: missing/empty transcript)
  1  usage or pipeline error
`;

function die(msg: string): never {
  process.stderr.write(`claude-session-summary: ${msg}\n`);
  process.exit(1);
}

function getGitRoot(dir: string): string | null {
  const result = Bun.spawnSync(["git", "-C", dir, "rev-parse", "--show-toplevel"], {
    stdout: "pipe",
    stderr: "pipe",
  });
  if (result.exitCode !== 0) return null;
  return result.stdout.toString().trim();
}

async function main(): Promise<void> {
  const args = process.argv.slice(2);

  if (args.includes("-h") || args.includes("--help")) {
    process.stdout.write(USAGE);
    process.exit(0);
  }

  const debug = args.includes("--debug");
  const dryRun = args.includes("--dry-run");

  const modeIdx = args.indexOf("--mode");
  const mode = modeIdx !== -1 ? args[modeIdx + 1] : undefined;

  if (mode !== "hook" && mode !== "summarize" && mode !== "problem-review") {
    die(`--mode is required and must be "hook", "summarize", or "problem-review"`);
  }

  let transcriptPath: string;
  let sessionId: string;
  let projectDir: string;

  if (mode === "problem-review") {
    const pdIdx = args.indexOf("--project-dir");
    const startDir = pdIdx !== -1 ? (args[pdIdx + 1] ?? die("--project-dir requires a value")) : process.cwd();
    const gitRoot = getGitRoot(startDir);
    if (!gitRoot) {
      info("not in a git repository, skipping");
      process.exit(0);
    }
    await problemReview(gitRoot);
    return;
  }

  if (mode === "summarize") {
    const tIdx = args.indexOf("--transcript");
    transcriptPath = tIdx !== -1 ? (args[tIdx + 1] ?? die("--transcript requires a path argument")) : die("--mode summarize requires --transcript");

    const sidIdx = args.indexOf("--session-id");
    sessionId = sidIdx !== -1 ? (args[sidIdx + 1] ?? die("--session-id requires a value")) : `cli-${Date.now()}`;

    const pdIdx = args.indexOf("--project-dir");
    projectDir = pdIdx !== -1 ? (args[pdIdx + 1] ?? die("--project-dir requires a value")) : process.cwd();
  } else {
    // Hook mode: read JSON from stdin
    const stdinText = await Bun.stdin.text();
    if (!stdinText.trim()) {
      process.exit(0);
    }

    let hookData: { session_id?: string; transcript_path?: string; cwd?: string };
    try {
      hookData = JSON.parse(stdinText) as typeof hookData;
    } catch {
      die("failed to parse hook input JSON");
    }

    sessionId = hookData.session_id ?? die("session_id missing from hook input");
    transcriptPath = hookData.transcript_path ?? die("transcript_path missing from hook input");
    projectDir = process.env.CLAUDE_PROJECT_DIR ?? hookData.cwd ?? die("cwd missing from hook input");
  }

  // Resolve to git root; exit early if not in a git repo
  const gitRoot = getGitRoot(projectDir);
  if (!gitRoot) {
    info("not in a git repository, skipping");
    process.exit(0);
  }
  projectDir = gitRoot;

  // Respect per-project opt-out: .jack.yaml with session_summary: false
  const jackYaml = join(projectDir, ".jack.yaml");
  if (existsSync(jackYaml)) {
    const jackYamlContent = readFileSync(jackYaml, "utf-8");
    if (/^\s*session_summary\s*:\s*false\s*$/m.test(jackYamlContent)) {
      info("session_summary disabled in .jack.yaml, skipping");
      process.exit(0);
    }
  }

  if (!existsSync(transcriptPath)) {
    info(`transcript not found: ${transcriptPath}`);
    process.exit(0);
  }

  if (statSync(transcriptPath).size === 0) {
    info(`transcript is empty: ${transcriptPath}`);
    process.exit(0);
  }

  try {
    await runPipeline({ claudeBin: CLAUDE_BIN, transcriptPath, sessionId, projectDir, debug, dryRun });
  } catch (e: unknown) {
    if (mode === "hook") {
      info(e instanceof Error ? e.message : String(e));
      process.exit(0);
    }
    throw e;
  }
}

main().catch((e: unknown) => {
  die(e instanceof Error ? e.message : String(e));
});
