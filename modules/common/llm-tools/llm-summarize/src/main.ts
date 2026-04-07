#!/usr/bin/env bun
// llm-summarize: one-shot Anthropic Messages API text transformer.
// Reads instructions from --instructions, text from stdin, API key from
// /run/agenix/anthropic-api-key, prints the model output to stdout.

const ANTHROPIC_URL = "https://api.anthropic.com/v1/messages";
const SECRET_PATH = "/run/agenix/anthropic-api-key";
const SYSTEM_PROMPT =
  "You are a text transformer. Output ONLY the transformed text, " +
  "nothing else. No preamble, no markdown fences, no meta-commentary.";
const ANTHROPIC_VERSION = "2023-06-01";
const DEFAULT_MODEL = "claude-haiku-4-5";
const DEFAULT_MAX_TOKENS = 512;
const SOFT_TIMEOUT_MS = 15_000;
const HARD_TIMEOUT_MS = 16_000;

const MODEL_ALIASES: Record<string, string> = {
  haiku: "claude-haiku-4-5",
  sonnet: "claude-sonnet-4-6",
  opus: "claude-opus-4-6",
};

const USAGE = `Usage: llm-summarize -i <instructions> [-m <model>] [-t <max-tokens>] < input

Reads text from stdin, transforms it according to <instructions> using the
Anthropic Messages API, and writes the result to stdout.

Flags:
  -i, --instructions <text>   (required) Transformation instructions
  -m, --model <id>            Model id or alias (haiku|sonnet|opus)
                              Default: claude-haiku-4-5
  -t, --max-tokens <n>        Max output tokens (default: 512)
  -h, --help                  Show this help and exit

Exit codes:
  0  success
  1  usage error
  2  secret missing/unreadable
  3  empty stdin
  4  authentication failure (HTTP 401/403)
  5  API error (other 4xx)
  6  upstream server error (5xx)
  7  network / connection error / timeout
  8  empty model response
  9  model refusal or error stop reason
`;

// ---------------------------------------------------------------------------
// Typed shapes for the Anthropic Messages API response
// ---------------------------------------------------------------------------

interface ApiContentBlock {
  type: string;
  text?: string;
}

interface ApiErrorBody {
  error?: {
    message?: string;
  };
}

interface ApiSuccessBody {
  content: ApiContentBlock[];
  stop_reason: string;
}

function isApiErrorBody(v: unknown): v is ApiErrorBody {
  return (
    v !== null &&
    typeof v === "object" &&
    (!("error" in v) ||
      (typeof (v as Record<string, unknown>).error === "object" &&
        (v as Record<string, unknown>).error !== null))
  );
}

function isApiSuccessBody(v: unknown): v is ApiSuccessBody {
  return (
    v !== null &&
    typeof v === "object" &&
    "content" in v &&
    Array.isArray((v as Record<string, unknown>).content) &&
    "stop_reason" in v &&
    typeof (v as Record<string, unknown>).stop_reason === "string"
  );
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

function die(code: number, msg: string): never {
  process.stderr.write(`llm-summarize: ${msg}\n`);
  process.exit(code);
}

function parseArgs(argv: string[]): {
  instructions: string;
  model: string;
  maxTokens: number;
} {
  let instructions: string | undefined;
  let model = DEFAULT_MODEL;
  let maxTokens = DEFAULT_MAX_TOKENS;

  for (let i = 0; i < argv.length; i++) {
    const a = argv[i];
    switch (a) {
      case "-h":
      case "--help":
        process.stdout.write(USAGE);
        process.exit(0);
        break;
      case "-i":
      case "--instructions":
        instructions = argv[++i];
        break;
      case "-m":
      case "--model": {
        const v = argv[++i];
        model = MODEL_ALIASES[v] ?? v;
        break;
      }
      case "-t":
      case "--max-tokens": {
        const v = parseInt(argv[++i], 10);
        if (!Number.isFinite(v) || v <= 0) die(1, `invalid --max-tokens: ${argv[i]}`);
        maxTokens = v;
        break;
      }
      default:
        die(1, `unknown argument: ${a}`);
    }
  }

  if (!instructions) die(1, "missing required --instructions / -i");
  return { instructions, model, maxTokens };
}

async function readSecret(): Promise<string> {
  try {
    return (await Bun.file(SECRET_PATH).text()).trim();
  } catch (e: unknown) {
    const msg = e instanceof Error ? e.message : String(e);
    die(2, `Secret missing or unreadable: ${SECRET_PATH}: ${msg}`);
  }
}

async function readStdin(): Promise<string> {
  const text = await Bun.stdin.text();
  if (text.length === 0) die(3, "empty stdin");
  return text;
}

async function callApi(
  apiKey: string,
  body: object,
): Promise<{ status: number; parsed: unknown; rawText: string }> {
  const controller = new AbortController();
  const hardDeadline = new Promise<never>((_, reject) =>
    setTimeout(() => {
      controller.abort();
      reject(new Error("hard deadline (16s) exceeded"));
    }, HARD_TIMEOUT_MS),
  );

  // AbortSignal.any combines the manual controller with a soft timeout.
  // Both are needed because Bun's AbortSignal.timeout is unreliable for
  // connection-level failures (issues #18536, #13302, #15275).
  const signal = AbortSignal.any([
    controller.signal,
    AbortSignal.timeout(SOFT_TIMEOUT_MS),
  ]);

  let res: Response;
  try {
    res = await Promise.race([
      fetch(ANTHROPIC_URL, {
        method: "POST",
        headers: {
          "content-type": "application/json",
          "x-api-key": apiKey,
          "anthropic-version": ANTHROPIC_VERSION,
        },
        body: JSON.stringify(body),
        signal,
      }),
      hardDeadline,
    ]);
  } catch (e: unknown) {
    const msg = e instanceof Error ? e.message : String(e);
    die(7, `network error: ${msg}`);
  }

  const rawText = await res.text();
  let parsed: unknown = null;
  try {
    parsed = JSON.parse(rawText) as unknown;
  } catch {
    /* leave parsed null */
  }
  return { status: res.status, parsed, rawText };
}

function extractText(body: ApiSuccessBody): string {
  return body.content
    .filter((b) => b.type === "text" && typeof b.text === "string")
    .map((b) => b.text ?? "")
    .join("");
}

// ---------------------------------------------------------------------------
// Main
// ---------------------------------------------------------------------------

async function main(): Promise<void> {
  const { instructions, model, maxTokens } = parseArgs(process.argv.slice(2));
  const apiKey = await readSecret();
  const input = await readStdin();

  const body = {
    model,
    max_tokens: maxTokens,
    system: SYSTEM_PROMPT,
    messages: [
      {
        role: "user",
        content: `${instructions}\n\n---\n\n${input}`,
      },
    ],
  };

  const { status, parsed, rawText } = await callApi(apiKey, body);

  if (status === 401 || status === 403) {
    die(4, `authentication failed (HTTP ${status}): ${rawText.slice(0, 200)}`);
  }
  if (status >= 400 && status < 500) {
    let apiMsg = rawText.slice(0, 200);
    if (isApiErrorBody(parsed)) {
      const errMsg = parsed.error?.message;
      if (typeof errMsg === "string") apiMsg = errMsg;
    }
    die(5, `API error (HTTP ${status}): ${apiMsg}`);
  }
  if (status >= 500) {
    die(6, `upstream server error (HTTP ${status})`);
  }
  if (parsed === null) {
    die(7, `non-JSON response: ${rawText.slice(0, 200)}`);
  }

  if (!isApiSuccessBody(parsed)) {
    die(7, `unexpected response shape: ${rawText.slice(0, 200)}`);
  }

  const { stop_reason: stopReason } = parsed;
  if (stopReason === "refusal" || stopReason === "error") {
    die(9, `model stop_reason=${stopReason}`);
  }

  const out = extractText(parsed).trim();
  if (out.length === 0) {
    die(8, "empty response");
  }

  if (stopReason === "max_tokens") {
    process.stderr.write("llm-summarize: warning: response truncated (max_tokens)\n");
  }

  process.stdout.write(out);
  process.exit(0);
}

main().catch((e: unknown) => {
  const msg = e instanceof Error ? e.message : String(e);
  die(7, `unexpected error: ${msg}`);
});
