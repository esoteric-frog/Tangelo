import Foundation
import Testing
@testable import TangeloCore

let sh = URL(fileURLWithPath: "/bin/sh")

@Test func successReturns() async throws {
    try await ToolRunner.run(sh, ["-c", "exit 0"])
}

@Test func failureCarriesStderr() async {
    do { try await ToolRunner.run(sh, ["-c", "echo bad input >&2; exit 3"]); Issue.record("no throw") }
    catch { #expect(error.localizedDescription.contains("bad input")) }
}

@Test func timeoutKillsTool() async {
    let start = Date()
    do { try await ToolRunner.run(sh, ["-c", "sleep 30"], timeout: 0.5); Issue.record("no throw") }
    catch { #expect(error.localizedDescription.contains("longer than")) }
    #expect(Date().timeIntervalSince(start) < 5)
}

@Test func missingToolSaysRebuild() async {
    do { try await ToolRunner.run(URL(fileURLWithPath: "/nope/cwebp"), []); Issue.record("no throw") }
    catch { #expect(error.localizedDescription.contains("missing cwebp")) }
}

@Test func bigStderrDoesNotHang() async throws {
    // 1 MB on stderr would fill the pipe buffer if nobody drained it.
    try await ToolRunner.run(sh, ["-c", "head -c 1000000 /dev/zero | tr '\\0' x >&2; exit 0"], timeout: 10)
}
