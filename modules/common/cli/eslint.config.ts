import eslint from "@eslint/js";
import tseslint from "typescript-eslint";
import solid from "eslint-plugin-solid/configs/typescript";

// Shell-out bans: for each banned filesystem command, generate selectors that
// catch the two ways it can appear:
//   1. Direct string arg:  exec("mkdir", ...) / Command.make("mkdir", ...)
//   2. Array arg in spawn: Bun.spawn(["mkdir", ...]) / Bun.spawnSync(["mkdir", ...])
const shellBans = [
  { cmd: "curl", alt: "fetch()" },
  { cmd: "mkdir", alt: "FileSystem.makeDirectory()" },
  { cmd: "rmdir", alt: "FileSystem.remove()" },
  { cmd: "rm", alt: "FileSystem.remove()" },
  { cmd: "cat", alt: "FileSystem.readFileString()" },
  { cmd: "ls", alt: "FileSystem.readDirectory()" },
  { cmd: "stat", alt: "FileSystem.stat()" },
  { cmd: "cp", alt: "FileSystem.copy()" },
  { cmd: "mv", alt: "FileSystem.rename()" },
  { cmd: "touch", alt: "FileSystem.writeFileString()" },
  { cmd: "chmod", alt: "FileSystem.chmod()" },
] as const;

const shellBanSelectors = shellBans.flatMap(({ cmd, alt }) => {
  const message = `Use ${alt} instead of shelling out to ${cmd}.`;
  return [
    // exec("cmd", ...) / Command.make("cmd", ...)
    { selector: `CallExpression[arguments.0.value='${cmd}']`, message },
    // Bun.spawn(["cmd", ...]) / Bun.spawnSync(["cmd", ...]) / *.execFile(["cmd", ...])
    { selector: `CallExpression[callee.property.name=/^spawn/] > ArrayExpression > Literal:first-child[value='${cmd}']`, message },
  ];
});

export default [
  { ignores: ["node_modules", "dist", ".build", "scripts", "eslint.config.ts"] },
  eslint.configs.recommended,
  ...tseslint.configs.strictTypeChecked,
  ...tseslint.configs.stylisticTypeChecked,
  {
    files: ["**/*.{ts,tsx}"],
    ...solid,
    languageOptions: {
      ...solid.languageOptions,
      parserOptions: { projectService: { allowDefaultProject: ["*.config.ts"] }, sourceType: "module" },
    },
    rules: {
      "@typescript-eslint/restrict-template-expressions": [
        "error",
        { allowNumber: true, allowBoolean: true },
      ],
      "@typescript-eslint/no-unnecessary-type-parameters": "off",
      // Disabled: noUncheckedIndexedAccess forces T|undefined on array indexing,
      // and ! is the standard escape hatch after length checks.
      "@typescript-eslint/no-non-null-assertion": "off",
      "@typescript-eslint/no-unused-vars": [
        "error",
        { argsIgnorePattern: "^_", varsIgnorePattern: "^_", destructuredArrayIgnorePattern: "^_" },
      ],
      // In Effect, errors are values — try/catch silently breaks Effect.gen generators
      // because yield* failures propagate through the Effect channel, not exceptions.
      // Use Effect.either, Effect.catchAll, or Effect.catchTag instead.
      "no-console": "error",
      "no-restricted-imports": [
        "error",
        {
          paths: [
            { name: "fs", message: "Use @effect/platform FileSystem service instead of Node.js fs." },
            { name: "node:fs", message: "Use @effect/platform FileSystem service instead of Node.js fs." },
            { name: "node:fs/promises", message: "Use @effect/platform FileSystem service instead of Node.js fs." },
            { name: "path", message: "Use @effect/platform Path service instead of Node.js path." },
            { name: "node:path", message: "Use @effect/platform Path service instead of Node.js path." },
            { name: "child_process", message: "Use @effect/platform Command or ShellService instead of Node.js child_process." },
            { name: "node:child_process", message: "Use @effect/platform Command or ShellService instead of Node.js child_process." },
          ],
        },
      ],
      "no-restricted-syntax": [
        "error",
        { selector: "TryStatement", message: "Use Effect.either or Effect.catchAll instead of try/catch. Errors are values in Effect." },
        { selector: "BinaryExpression[operator='==='][left.property.name='_tag'][right.value='Right']", message: "Use Either.isRight() instead of _tag === 'Right'." },
        { selector: "BinaryExpression[operator='==='][left.property.name='_tag'][right.value='Left']", message: "Use Either.isLeft() instead of _tag === 'Left'." },
        { selector: "ImportDeclaration[source.value=/\\.js$/]", message: "Import .ts files directly without the .js extension. Bun's bundler resolves extensionless imports." },
        { selector: "ImportNamespaceSpecifier", message: "Avoid 'import * as X' namespace imports. Use named imports instead (e.g. import { Command } from '@effect/platform')." },
        ...shellBanSelectors,
        { selector: "TSTypeReference[typeName.left.name='Effect'][typeName.right.name='Effect'] > TSTypeParameterInstantiation > TSUnknownKeyword", message: "Do not use 'unknown' in Effect.Effect type parameters. Use specific error and service types to preserve Effect's compile-time safety." },
        { selector: "CallExpression[callee.property.name='makeTempDirectory']", message: "Use makeTempDirectoryScoped() instead — it auto-cleans up when the scope finalizer runs." },
        { selector: "CallExpression[callee.property.name='makeTempFile']", message: "Use makeTempFileScoped() instead — it auto-cleans up when the scope finalizer runs." },
        { selector: "TSImportType", message: "Use a top-level import instead of inline import('...') type annotations." },
        { selector: "ClassDeclaration[superClass.callee.property.name='TaggedError'] TSTypeLiteral:not(:has(TSPropertySignature[key.name='cause']))", message: "TaggedError must include a 'cause?: unknown' field for error chaining." },
        { selector: ":function > TSTypeAnnotation > TSTypeReference[typeName.left.name='Effect'][typeName.right.name='Effect']", message: "Don't explicitly type Effect return types — let TypeScript infer them. Explicit annotations duplicate what inference provides and can drift from the real type, causing unnecessary widening." },
        { selector: "MemberExpression[object.name='Console'][property.name=/^(log|error|warn|info|debug)$/]", message: "Use Effect.log / Effect.logWarning / Effect.logError instead of Console.log. Effect's logger respects log levels, structured annotations, and can be tested without mocking Console." },
        { selector: "ReturnStatement > Literal[value=null]", message: "Don't return null. Use Option.none() when absence is a normal outcome, or Effect.fail() for unexpected failures." },
        { selector: "ReturnStatement > Identifier[name='undefined']", message: "Don't return undefined explicitly. Use Option.none() when absence is a normal outcome, or Effect.fail() for unexpected failures." },
      ],
    },
  },
  {
    files: ["**/*.test.ts"],
    rules: {
      "@typescript-eslint/no-unsafe-assignment": "off",
      "@typescript-eslint/no-unsafe-member-access": "off",
      "@typescript-eslint/no-unsafe-call": "off",
      "@typescript-eslint/no-unsafe-return": "off",
      "@typescript-eslint/no-unsafe-argument": "off",
      "@typescript-eslint/no-explicit-any": "off",
      "@typescript-eslint/require-await": "off",
      "@typescript-eslint/no-non-null-assertion": "off",
      "no-console": "off",
      "no-restricted-imports": "off",
    },
  },
];
