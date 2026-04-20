import { createSolidTransformPlugin } from "@opentui/solid/bun-plugin"
import { $ } from "bun"
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
// This plugin intercepts the pre-bundled @opentui/core file during Step 1 and
// replaces the template literal with a static string for the current platform.
// Bun then bundles @opentui/core-linux-x64/index.ts, which in turn embeds
// libopentui.so via `import("./libopentui.so", { with: { type: "file" } })`
// — the standard Bun pattern for native assets in compiled binaries.
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

// Step 1: Bundle with Solid JSX transform plugin + OpenTUI native resolve plugin.
// (bun build --compile doesn't support plugins, so we bundle first)
const result = await Bun.build({
  entrypoints: ["src/main.ts"],
  outdir: ".build",
  target: "bun",
  plugins: [createSolidTransformPlugin(), resolveOpenTuiNativePlugin],
})

if (!result.success) {
  for (const log of result.logs) {
    // eslint-disable-next-line no-console
    console.error(log)
  }
  process.exit(1)
}

// Step 2: Compile bundled JS to standalone executable
await $`bun build --compile .build/main.js --outfile dist/j`
