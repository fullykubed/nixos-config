import { Effect } from "effect"
import { DEFAULT_CONFIG } from "../config-defaults"
import type { ProjectConfig } from "../config-types"
import { ProjectPath, ProjectId, GitCommonPath } from "../types"

export type MockProjectConfigResult = ProjectConfig & {
  name: string
  tmux_session: string
  projectPath: ProjectPath
  gitCommonDir: GitCommonPath
  projectId: ProjectId
}

const MOCK_PROJECT_CONFIG: MockProjectConfigResult = {
  ...DEFAULT_CONFIG,
  name: "repo",
  tmux_session: "repo",
  projectPath: ProjectPath("/mock/repo"),
  gitCommonDir: GitCommonPath("/mock/repo/.git"),
  projectId: ProjectId("00000000-0000-0000-0000-000000000000"),
}

export const mockGetProjectConfig = (overrides?: Partial<MockProjectConfigResult>) =>
  (_dir?: unknown) => Effect.succeed({ ...MOCK_PROJECT_CONFIG, ...overrides } as MockProjectConfigResult)
