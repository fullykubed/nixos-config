/**
 * Parse the raw arguments to detect -- separator and extract remote command
 */
export const parseRemoteCommand = (rawArgs: readonly string[], _builderName: string): string[] => {
  // Find the -- separator in raw args
  const separatorIndex = rawArgs.indexOf("--")

  if (separatorIndex === -1) {
    // No separator, no remote command
    return []
  }

  // Everything after -- is the remote command
  return [...rawArgs.slice(separatorIndex + 1)]
}
