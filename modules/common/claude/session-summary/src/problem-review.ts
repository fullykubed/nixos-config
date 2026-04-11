// problem-review: interactive dashboard for reviewing and acting on logged problems.
//
// Reads all .claude/log/*.json files, presents problems via fzf, and allows the
// user to either address a problem with workmux (wmab) or delete it from the file.
//
// Keys in fzf:
//   w      - address with workmux (generates branch name via Claude, runs workmux add)
//   d      - delete problem from its log file
//   ctrl-c - quit
// Preview pane shows the full problem text for the selected item.

import { existsSync, mkdtempSync, readdirSync, readFileSync, rmSync, writeFileSync } from "fs";
import { join } from "path";
import { tmpdir } from "os";

interface LogEntry {
  session_id: string;
  timestamp: string;
  problems?: string[];
}

interface ProblemRef {
  text: string;
  sourceFile: string;
  index: number;
  sessionId: string;
  timestamp: string;
}

function collectProblems(logDir: string): ProblemRef[] {
  const refs: ProblemRef[] = [];

  const files = readdirSync(logDir)
    .filter((f) => f.endsWith(".json"))
    .sort()
    .reverse(); // newest first

  for (const file of files) {
    const filePath = join(logDir, file);
    let entry: LogEntry;
    try {
      entry = JSON.parse(readFileSync(filePath, "utf-8")) as LogEntry;
    } catch {
      continue;
    }
    if (!entry.problems?.length) continue;
    for (let i = 0; i < entry.problems.length; i++) {
      refs.push({
        text: entry.problems[i]!,
        sourceFile: filePath,
        index: i,
        sessionId: entry.session_id,
        timestamp: entry.timestamp,
      });
    }
  }

  return refs;
}

function deleteProblem(problem: ProblemRef): void {
  const entry = JSON.parse(readFileSync(problem.sourceFile, "utf-8")) as LogEntry;
  if (entry.problems) {
    entry.problems.splice(problem.index, 1);
    writeFileSync(problem.sourceFile, JSON.stringify(entry, null, 2) + "\n");
  }
}

function addressWithWorkmux(problem: ProblemRef): void {
  Bun.spawn(["wmab", problem.text], { stdout: "ignore", stderr: "ignore", stdin: "ignore" });
}

// Run fzf with the current problem list. Returns { key, problem } or null if quit.
function selectProblem(
  problems: ProblemRef[],
): { key: string; problem: ProblemRef } | null {
  if (problems.length === 0) return null;

  // Write each problem's full text to a temp file named by its padded index,
  // so the fzf --preview command can read it with `cat TMPDIR/{1}`.
  const tmpDir = mkdtempSync(join(tmpdir(), "problem-review-"));
  try {
    for (let i = 0; i < problems.length; i++) {
      const p = problems[i]!;
      const date = new Date(p.timestamp).toLocaleDateString("en-CA");
      const hr = "─".repeat(60);
      const content = `Session: ${p.sessionId}  Date: ${date}\n${hr}\n\n${p.text}\n`;
      writeFileSync(join(tmpDir, String(i).padStart(4, "0")), content);
    }

    // Tab-delimited: INDEX\tDATE  PROBLEM_TEXT
    // --with-nth=2 hides the index from display but keeps it for parsing and preview.
    const input = problems
      .map((p, i) => {
        const date = new Date(p.timestamp).toLocaleDateString("en-CA"); // YYYY-MM-DD
        return `${String(i).padStart(4, "0")}\t${date}  ${p.text}`;
      })
      .join("\n");

    const result = Bun.spawnSync(
      [
        "fzf",
        "--delimiter=\t",
        "--with-nth=2",
        "--expect=w,d",
        "--header=w: address with workmux  d: delete  ctrl-c: quit",
        "--prompt=Problem> ",
        "--height=80%",
        "--layout=reverse",
        "--info=inline",
        `--preview=cat ${tmpDir}/{1}`,
        "--preview-window=right:50%:wrap",
      ],
      {
        stdin: Buffer.from(input),
        stdout: "pipe",
        stderr: "inherit",
      },
    );

    if (result.exitCode !== 0) return null; // ctrl-c or no match

    const lines = result.stdout.toString().split("\n");
    const key = lines[0]?.trim() ?? "";
    const selected = lines[1]?.trim() ?? "";
    if (!selected) return null;

    const idxStr = selected.split("\t")[0]?.trim() ?? "";
    const idx = parseInt(idxStr, 10);
    if (isNaN(idx) || idx < 0 || idx >= problems.length) return null;

    return { key, problem: problems[idx]! };
  } finally {
    rmSync(tmpDir, { recursive: true });
  }
}

export async function problemReview(projectDir: string): Promise<void> {
  const logDir = join(projectDir, ".claude", "log");

  if (!existsSync(logDir)) {
    process.stderr.write("claude-session-summary: no log directory found\n");
    return;
  }

  while (true) {
    const problems = collectProblems(logDir);

    if (problems.length === 0) {
      process.stdout.write("No problems found.\n");
      break;
    }

    const selection = selectProblem(problems);
    if (!selection) break;

    const { key, problem } = selection;

    if (key === "d") {
      deleteProblem(problem);
      process.stderr.write("claude-session-summary: problem deleted\n");
    } else if (key === "w") {
      addressWithWorkmux(problem);
    }
    // enter/no key: loop without action
  }
}
