// Format memory in human-readable format
export function formatMemory(kb: number): string {
  if (kb > 1024 * 1024) {
    return `${(kb / (1024 * 1024)).toFixed(1)}GB`
  } else if (kb > 1024) {
    return `${(kb / 1024).toFixed(1)}MB`
  } else {
    return `${kb}KB`
  }
}
