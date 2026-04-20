export const BUILDER_CONFIG = {
  regularServerType: "cpx62",
  regularFallbackServerType: "cpx52",
  bigServerType: "ccx63",
  location: "hel1",
  sshPort: 3098,
  regularCostPerHour: 0.0534,
  bigCostPerHour: 0.0950,
  builderPattern: /^(big-)?builder-\d+$/,
} as const