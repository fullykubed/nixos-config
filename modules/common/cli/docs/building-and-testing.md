# Building and Testing

All commands run from `modules/common/cli/`.

## Tests

```bash
bun run test
```

## Coverage

Run unit test coverage:

```bash
bun run test:coverage
```

This outputs a terminal summary and writes lcov data to `coverage/unit/lcov.info`.

Run integration test coverage (requires tmux):

```bash
bun run test:coverage:integration
```

This writes to `coverage/integration/lcov.info`.

## Type-check

```bash
bun run typecheck
```

## Lint

```bash
bun run lint
```

## Build standalone binary

```bash
bun run build
```

Produces a self-contained ELF binary with the Bun runtime embedded.
