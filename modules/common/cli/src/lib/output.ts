/**
 * Output formatting utilities for structured command output.
 * Supports the --json flag convention.
 *
 * For logging (status messages, progress, errors), use Effect.log / Effect.logWarning / Effect.logError.
 */

/**
 * Render a table with aligned columns to stdout.
 * Auto-calculates column widths based on content.
 */
export const table = (headers: string[], rows: string[][]): void => {
  const widths = headers.map((header, i) =>
    Math.max(header.length, ...rows.map(row => (row[i] ?? '').length))
  )

  process.stdout.write(headers.map((header, i) => header.padEnd(widths[i]!)).join('  ') + '\n')

  for (const row of rows) {
    process.stdout.write(row.map((cell, i) => cell.padEnd(widths[i]!)).join('  ') + '\n')
  }
}

/**
 * Render JSON to stdout with pretty formatting.
 */
export const json = (data: unknown): void => {
  process.stdout.write(JSON.stringify(data, null, 2) + '\n')
}

/**
 * Output data in either table or JSON format based on options.
 */
