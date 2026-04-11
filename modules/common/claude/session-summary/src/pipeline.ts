// Summarization pipeline: preprocess transcript and call Claude for structured output.

import { mkdirSync, unlinkSync, writeFileSync } from "fs";
import { join } from "path";
import { preprocessTranscript } from "./preprocess.ts";

const JSON_SCHEMA = JSON.stringify({
  type: "object",
  properties: {
    changes: {
      type: "array",
      items: {
        type: "object",
        properties: {
          motivation: { type: "string" },
          summary: { type: "string" },
        },
        required: ["motivation", "summary"],
        additionalProperties: false,
      },
    },
    problems: {
      type: "array",
      items: { type: "string" },
    },
  },
  required: ["changes", "problems"],
  additionalProperties: false,
});

const PROMPT = `Summarize this Claude Code session transcript. Return ONLY valid JSON matching the provided schema.

The output should include:
- changes: Array of significant changes made, each with motivation (why) and summary (what). Write for a future developer or end-user who needs to understand what changed and why — not a session narrative. Ignore PRD workflow steps (creating PRDs, planning tasks, running prd-worker agents, implementing PRD tasks) — only include the actual code or config changes that resulted.
- problems: Array of execution problems the agent ran into that could be avoided in the future — e.g. confusing variable names, misnamed files, bugs discovered, misleading comments, or repeated tool failures caused by unclear interfaces. Pay special attention to documentation gaps: missing docs, out-of-date docs, undocumented behaviour, or anything the agent had to discover by trial and error that should have been documented. Do NOT include incomplete tasks, unfinished work, or anything that is simply a matter of more work being needed. Only include issues where better code, docs, or naming would have prevented the problem.

Focus on meaningful changes and real problems. Be concise but informative.`;

function die(msg: string): never {
  throw new Error(msg);
}

export function info(msg: string): void {
  process.stderr.write(`claude-session-summary: ${msg}\n`);
}

export async function runPipeline(args: {
  claudeBin: string;
  transcriptPath: string;
  sessionId: string;
  projectDir: string;
  debug: boolean;
  dryRun: boolean;
}): Promise<void> {
  const { claudeBin, transcriptPath, sessionId, projectDir, debug, dryRun } = args;

  const logDir = join(projectDir, ".claude", "log");
  const backgroundDir = join(projectDir, ".claude", "background");

  mkdirSync(logDir, { recursive: true });
  mkdirSync(backgroundDir, { recursive: true });

  const outputFile = join(logDir, `${Date.now()}.json`);
  const markerFile = join(backgroundDir, sessionId);

  writeFileSync(markerFile, "");
  info(`marker: ${markerFile}`);

  const onSignal = () => {
    try { unlinkSync(markerFile); } catch { /* already gone */ }
    process.exit(0);
  };
  process.once("SIGINT", onSignal);
  process.once("SIGTERM", onSignal);

  try {
    const condensed = preprocessTranscript(transcriptPath);

    if (!condensed.trim()) {
      info("transcript produced no output after preprocessing, skipping");
      return;
    }

    if (debug) {
      process.stderr.write("=== condensed transcript sent to claude ===\n");
      process.stderr.write(condensed + "\n");
      process.stderr.write("===========================================\n");
    }

    const { CLAUDECODE: _omit, ...envWithoutClaudeCode } = process.env as Record<string, string>;
    const claudeResult = Bun.spawnSync(
      [
        claudeBin,
        "--print",
        "--model", "sonnet",
        "--allowedTools", "Read,Glob,Grep,WebSearch,WebFetch,Task,mcp__exa__web_search_exa,mcp__exa__get_code_context_exa",
        "--no-session-persistence",
        "--output-format", "json",
        "--json-schema", JSON_SCHEMA,
        PROMPT,
      ],
      {
        stdin: new Response(condensed),
        stdout: "pipe",
        stderr: "inherit",
        env: { ...envWithoutClaudeCode, CLAUDE_HOOK_RECURSIVE: "1" },
      },
    );

    if (claudeResult.exitCode !== 0) {
      die(`claude --print exited with code ${claudeResult.exitCode}`);
    }

    const claudeOutput = JSON.parse(claudeResult.stdout.toString()) as {
      structured_output?: Record<string, unknown>;
    };

    const logEntry = {
      ...(claudeOutput.structured_output ?? {}),
      session_id: sessionId,
      timestamp: new Date().toISOString(),
    };

    if (dryRun) {
      process.stdout.write(JSON.stringify(logEntry, null, 2) + "\n");
      info(`dry-run: would have written to ${outputFile}`);
    } else {
      writeFileSync(outputFile, JSON.stringify(logEntry, null, 2) + "\n");
    }
  } finally {
    process.off("SIGINT", onSignal);
    process.off("SIGTERM", onSignal);
    try {
      unlinkSync(markerFile);
    } catch {
      // marker already gone
    }
  }
}
