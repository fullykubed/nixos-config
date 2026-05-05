# Building and Testing

All commands run from `modules/common/cli/`.

## Tests

```bash
bun test
```

~215 tests across 26 files. Each service method has a dedicated `.test.ts` file with mocked dependencies.

## Type-check

```bash
bun run typecheck    # tsc --noEmit
```

## Lint

```bash
bun run lint
```

ESLint with `strictTypeChecked` + `stylisticTypeChecked`. The `no-restricted-syntax` rule bans `try/catch` — all error handling must go through Effect channels.

## Build standalone binary

```bash
bun run build        # bun build --compile → j binary
```

Produces a self-contained ELF binary (~44 MB) with the Bun runtime embedded.

## Nix derivation

The Nix derivation (`default.nix`) uses `bun2nix-cli.mkDerivation` to produce the final `/bin/j` binary in the system closure. To regenerate the lockfile after changing dependencies:

```bash
bun2nix -o bun.nix
```
