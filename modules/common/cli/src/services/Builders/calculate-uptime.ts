export const calculateUptimeHours = (createdIso: string): number => {
  const created = new Date(createdIso)
  const now = new Date()
  const diffMs = now.getTime() - created.getTime()
  return diffMs / (1000 * 60 * 60) // Convert to hours
}
