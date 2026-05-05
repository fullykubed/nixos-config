// Strip GIT_* env vars that `git commit` injects when running pre-commit hooks.
// @effect/platform-node-shared merges process.env into every child process's env,
// so we must delete them here to prevent child git processes from operating on the
// parent repo instead of test tmp dirs.
delete process.env.GIT_DIR
delete process.env.GIT_INDEX_FILE
delete process.env.GIT_WORK_TREE
delete process.env.GIT_COMMON_DIR
delete process.env.GIT_OBJECT_DIRECTORY
