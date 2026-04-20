import { Effect, Either } from "effect"
import * as readline from "node:readline"
import type { ParsedCommand } from "../../../cli/types"
import { HcloudService } from "../../../services/Hcloud"
import { json } from "../../../lib/output"

export const cleanupHandler = (parsed: ParsedCommand) =>
  Effect.gen(function* () {
    const hcloud = yield* HcloudService
    const isJson = parsed.flags.get("json") === true
    const skipConfirmation = parsed.flags.get("yes") === true

    // List all builder snapshots
    const images = yield* hcloud.listImages("snapshot", { type: "builder" })

    // Sort by creation date (ISO 8601 timestamp)
    const sortedImages = [...images].sort((a, b) => a.created.localeCompare(b.created))

    // If 0 or 1 snapshots, nothing to clean up
    if (sortedImages.length <= 1) {
      if (isJson) {
        json([])
      } else {
        yield* Effect.log(`Nothing to clean up (${sortedImages.length} snapshot${sortedImages.length === 1 ? '' : 's'}).`)
      }
      return
    }

    // Keep the latest (last after sort), mark rest for deletion
    const latest = sortedImages[sortedImages.length - 1]!
    const toDelete = sortedImages.slice(0, -1)

    // For JSON mode, output what would be deleted without interactive prompt
    if (isJson) {
      const deleteList = toDelete.map(image => ({
        id: image.id,
        description: image.description ?? image.name ?? `Created ${image.created}`,
        created: image.created
      }))
      json(deleteList)
      return
    }

    // Show what will be deleted
    yield* Effect.log(`Found ${sortedImages.length} builder snapshots, keeping latest (ID: ${latest.id})`)
    yield* Effect.log(`\nWill delete ${toDelete.length} old snapshot${toDelete.length === 1 ? '' : 's'}:`)

    for (const image of toDelete) {
      const description = image.description ?? image.name ?? `Created ${image.created}`
      yield* Effect.log(`  ${image.id} - ${description} (${image.created})`)
    }

    // Ask for confirmation unless --yes flag is set
    if (!skipConfirmation) {
      yield* Effect.log("")
      process.stdout.write("Delete these snapshots? [y/N] ")

      const rl = readline.createInterface({
        input: process.stdin,
        output: process.stdout
      })

      const answer = yield* Effect.promise(() =>
        new Promise<string>((resolve) => {
          rl.question("", (answer: string) => {
            rl.close()
            resolve(answer.trim().toLowerCase())
          })
        })
      )

      if (answer !== "y" && answer !== "yes") {
        yield* Effect.log("Cancelled.")
        return
      }
    }

    // Delete old images
    let deleted = 0
    for (const image of toDelete) {
      const result = yield* hcloud.deleteImage(image.id).pipe(Effect.either)
      if (Either.isRight(result)) {
        const description = image.description ?? image.name ?? `Created ${image.created}`
        yield* Effect.log(`Deleted snapshot ${image.id} (${description})`)
        deleted++
      } else {
        yield* Effect.logError(`Failed to delete snapshot ${image.id}: ${String(result.left)}`)
      }
    }

    yield* Effect.log(`Deleted ${deleted} old snapshot${deleted === 1 ? '' : 's'}, kept latest`)
  })
