import { Schema } from "effect"
import { ProjectConfigSchema } from "./config-types"
import type { ProjectConfig } from "./config-types"

export const DEFAULT_CONFIG: ProjectConfig = Schema.decodeUnknownSync(ProjectConfigSchema)({})
