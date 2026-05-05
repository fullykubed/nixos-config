import { createSolidTransformPlugin } from "@opentui/solid/bun-plugin"
import { renameSync } from "fs"
import type { BunPlugin } from "bun"

// @opentui/core loads its native library via a dynamic import with a template
// literal so it can detect the platform at runtime:
//
//   var module = await import(`@opentui/core-${process.platform}-${process.arch}/index.ts`)
//
// Template-literal dynamic imports cannot be statically resolved by bundlers,
// so the reference survives into the bundle and causes `bun build --compile` to
// fail with "Could not resolve: @opentui/core-linux-x64/index.ts".
//
// This plugin intercepts the pre-bundled @opentui/core file and replaces the
// template literal with a static string for the current platform. Bun then
// bundles @opentui/core-linux-x64/index.ts, which in turn embeds libopentui.so
// via `import("./libopentui.so", { with: { type: "file" } })` — the standard
// Bun pattern for native assets in compiled binaries.
//
// Upstream issue: https://github.com/anomalyco/opentui/issues/355
const resolveOpenTuiNativePlugin: BunPlugin = {
  name: "resolve-opentui-native",
  setup(build) {
    build.onLoad(
      { filter: /node_modules\/@opentui\/core\/index-[a-z0-9]+\.js$/ },
      async ({ path }) => {
        const text = await Bun.file(path).text()
        const patched = text.replace(
          /await import\(`@opentui\/core-\$\{process\.platform\}-\$\{process\.arch\}\/index\.ts`\)/,
          `await import("@opentui/core-${process.platform}-${process.arch}/index.ts")`
        )
        return { contents: patched, loader: "js" }
      }
    )
  }
}

// Single-step compile: bundle + compile in one pass so file-type imports
// (like libopentui.so) are properly tracked and embedded into the binary.
const define: Record<string, string> = {}
if (process.env.J_PRODUCTION) {
  define["process.env.J_PRODUCTION"] = JSON.stringify(process.env.J_PRODUCTION)
}

const result = await Bun.build({
  entrypoints: ["src/main.ts"],
  outdir: "dist",
  compile: true,
  define,
  plugins: [createSolidTransformPlugin(), resolveOpenTuiNativePlugin],
})

if (!result.success) {
  for (const log of result.logs) {
    // eslint-disable-next-line no-console
    console.error(log)
  }
  process.exit(1)
}

// Bun.build names the output after the entrypoint ("main"), rename to "j"
renameSync("dist/main", "dist/j")
