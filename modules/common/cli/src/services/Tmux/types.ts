export interface TmuxWindow {
  readonly id: string
  readonly index: number
  readonly name: string
  readonly active: boolean
}

export interface SplitPaneOptions {
  readonly direction: "horizontal" | "vertical"
  readonly percentage?: number
  readonly cwd?: string
  readonly target?: string
}

export interface CreateWindowOptions {
  readonly name: string
  readonly cwd: string
  readonly command?: string
}