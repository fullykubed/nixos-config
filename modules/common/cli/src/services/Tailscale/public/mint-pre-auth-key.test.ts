import { describe, it, expect } from "bun:test"
import { Context, Effect, Exit } from "effect"
import { FileSystem, HttpClient, HttpClientError, HttpClientRequest, HttpClientResponse } from "@effect/platform"

import { mintPreAuthKey } from "./mint-pre-auth-key"

function extractFailureTag(exit: Exit.Exit<unknown, unknown>): string | undefined {
  if (Exit.isSuccess(exit)) return undefined
  const cause = exit.cause
  if (cause._tag === "Fail") return (cause.error as { _tag?: string })._tag
  return undefined
}

const mockFs = FileSystem.FileSystem.of({
  readFileString: () => Effect.succeed("test-api-key"),
} as any)

const noKeyFs = FileSystem.FileSystem.of({
  readFileString: () => Effect.fail(new Error("ENOENT")),
} as any)

const mockHttp = (...responses: Response[]) => {
  let i = 0
  return HttpClient.make((request) =>
    Effect.succeed(HttpClientResponse.fromWeb(request, responses[i++]!))
  )
}

const provide = (fs: FileSystem.FileSystem, http: HttpClient.HttpClient) =>
  Effect.provide(Context.empty().pipe(
    Context.add(FileSystem.FileSystem, fs),
    Context.add(HttpClient.HttpClient, http),
  ))

describe("mintPreAuthKey", () => {
  it("returns pre-auth key on success", async () => {
    const http = mockHttp(
      Response.json({ preAuthKey: { key: "hskey-preauth-abc123" } }),
    )

    const result = await Effect.runPromise(
      mintPreAuthKey().pipe(provide(mockFs, http))
    )
    expect(result).toBe("hskey-preauth-abc123")
  })

  it("sends correct request to headscale API", async () => {
    const requests: HttpClientRequest.HttpClientRequest[] = []
    const http = HttpClient.make((request) => {
      requests.push(request)
      return Effect.succeed(HttpClientResponse.fromWeb(
        request,
        Response.json({ preAuthKey: { key: "hskey-preauth-test" } }),
      ))
    })

    await Effect.runPromise(
      mintPreAuthKey().pipe(provide(mockFs, http))
    )

    expect(requests[0]!.url).toContain("/preauthkey")
    expect(requests[0]!.method).toBe("POST")
  })

  it("fails with HeadscalePreAuthError when API key is missing", async () => {
    const http = mockHttp(Response.json({}))

    const exit = await Effect.runPromiseExit(
      mintPreAuthKey().pipe(provide(noKeyFs, http))
    )
    expect(Exit.isFailure(exit)).toBe(true)
    expect(extractFailureTag(exit)).toBe("HeadscalePreAuthError")
  })

  it("fails with HeadscalePreAuthError on non-OK response", async () => {
    const http = mockHttp(
      new Response(null, { status: 401, statusText: "Unauthorized" }),
    )

    const exit = await Effect.runPromiseExit(
      mintPreAuthKey().pipe(provide(mockFs, http))
    )
    expect(Exit.isFailure(exit)).toBe(true)
    expect(extractFailureTag(exit)).toBe("HeadscalePreAuthError")
    if (Exit.isFailure(exit) && exit.cause._tag === "Fail") {
      const error = exit.cause.error as { message: string }
      expect(error.message).toContain("401")
    }
  })

  it("fails with HeadscalePreAuthError when response has no key", async () => {
    const http = mockHttp(
      Response.json({ preAuthKey: {} }),
    )

    const exit = await Effect.runPromiseExit(
      mintPreAuthKey().pipe(provide(mockFs, http))
    )
    expect(Exit.isFailure(exit)).toBe(true)
    expect(extractFailureTag(exit)).toBe("HeadscalePreAuthError")
    if (Exit.isFailure(exit) && exit.cause._tag === "Fail") {
      const error = exit.cause.error as { message: string }
      expect(error.message).toContain("did not contain")
    }
  })

  it("fails with HeadscalePreAuthError when response has no preAuthKey", async () => {
    const http = mockHttp(
      Response.json({}),
    )

    const exit = await Effect.runPromiseExit(
      mintPreAuthKey().pipe(provide(mockFs, http))
    )
    expect(Exit.isFailure(exit)).toBe(true)
    expect(extractFailureTag(exit)).toBe("HeadscalePreAuthError")
  })

  it("fails with HeadscalePreAuthError on network error", async () => {
    const http = HttpClient.make((request) =>
      Effect.fail(new HttpClientError.RequestError({
        request,
        reason: "Transport",
        cause: new Error("Network unreachable"),
      }))
    )

    const exit = await Effect.runPromiseExit(
      mintPreAuthKey().pipe(provide(mockFs, http))
    )
    expect(Exit.isFailure(exit)).toBe(true)
    expect(extractFailureTag(exit)).toBe("HeadscalePreAuthError")
    if (Exit.isFailure(exit) && exit.cause._tag === "Fail") {
      const error = exit.cause.error as { message: string }
      expect(error.message).toContain("reach headscale API")
    }
  })
})
