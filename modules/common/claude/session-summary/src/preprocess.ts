// Transcript preprocessing: condense Claude Code JSONL for LLM summarization.

import { readFileSync } from "fs";

interface TranscriptEntry {
  type: "user" | "assistant" | "progress" | "file-history-snapshot" | "system" | "queue-operation";
  message?: {
    role: string;
    content: string | ContentBlock[];
  };
  isMeta?: boolean;
}

interface ContentBlock {
  type: "text" | "tool_use" | "tool_result" | "thinking";
  text?: string;
  name?: string;
  input?: Record<string, unknown>;
}

function toolStub(name: string, input: Record<string, unknown>): string {
  switch (name) {
    case "Read":
    case "Edit":
    case "Write":
      return `${name}: ${input.file_path}`;
    case "Bash":
      return `Bash: ${String(input.command).slice(0, 120)}`;
    case "Grep":
      return "";
    case "Glob":
      return `Glob: ${input.pattern}`;
    case "TaskCreate":
    case "TaskUpdate":
    case "TaskGet":
    case "TaskList":
      return "";
    case "AskUserQuestion": {
      const questions = input.questions as Array<{ question: string }>;
      return `AskUserQuestion: ${questions?.[0]?.question?.slice(0, 80) ?? "(no question)"}`;
    }
    case "Skill":
      return `Skill: ${input.skill}`;
    case "WebSearch":
      return `WebSearch: ${input.query}`;
    case "WebFetch":
      return "";
    case "NotebookEdit":
      return `NotebookEdit: ${input.notebook_path}`;
    case "EnterWorktree":
      return `EnterWorktree: ${input.name || "(new worktree)"}`;
    case "Task": {
      const desc =
        (input.description as string | undefined) ??
        (input.prompt as string | undefined)?.split("\n")[0] ??
        "";
      return desc ? `Task: ${desc}` : "";
    }
    default:
      return `${name}: (invoked)`;
  }
}

function processContentBlocks(content: string | ContentBlock[]): string {
  if (typeof content === "string") return content;

  const parts: string[] = [];
  for (const block of content) {
    switch (block.type) {
      case "text":
        if (block.text) parts.push(block.text);
        break;
      case "tool_use": {
        if (block.name && block.input) {
          const stub = toolStub(block.name, block.input);
          if (stub) parts.push(stub);
        }
        break;
      }
      case "tool_result":
      case "thinking":
        break;
      default:
        if (block.text) parts.push(block.text);
        break;
    }
  }
  return parts.join("\n\n");
}

export function preprocessTranscript(filePath: string): string {
  const fileContent = readFileSync(filePath, "utf-8");
  if (fileContent.trim().length === 0) return "";

  const lines = fileContent.trim().split("\n");
  const outputParts: string[] = [];

  for (let i = 0; i < lines.length; i++) {
    const line = lines[i]!.trim();
    if (line.length === 0) continue;

    let entry: TranscriptEntry;
    try {
      entry = JSON.parse(line) as TranscriptEntry;
    } catch (e: unknown) {
      throw new Error(`Invalid JSON on line ${i + 1}: ${String(e)}`);
    }

    if (
      entry.type === "progress" ||
      entry.type === "file-history-snapshot" ||
      entry.type === "system" ||
      entry.type === "queue-operation" ||
      (entry.type === "user" && entry.isMeta)
    ) {
      continue;
    }

    if (entry.message) {
      const role = entry.message.role;
      const content = processContentBlocks(entry.message.content);
      if (content.trim().length > 0) {
        const roleLabel = role === "user" ? "User" : "Assistant";
        outputParts.push(`--- ${roleLabel} ---`);
        outputParts.push(content.trim());
        outputParts.push("");
      }
    }
  }

  return outputParts.join("\n").trim();
}
