export interface BuilderSummary {
  regularCount: number
  bigCount: number
  totalCount: number
  regularCost: number
  bigCost: number
  totalCost: number
}

export interface BuilderDetails {
  name: string
  status: string
  ip: string
  serverType: string
  uptimeHours: number
  costPerHour: number
  totalCost: number
}

export interface StatusOutput {
  summary: BuilderSummary
  builders: BuilderDetails[]
}
