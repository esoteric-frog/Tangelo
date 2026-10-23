import Foundation
import Testing
@testable import TangeloCore

@MainActor
func waitUntilFinished(_ q: JobQueue, seconds: Double = 30) async throws {
    let end = Date().addingTimeInterval(seconds)
    while q.jobs.contains(where: { $0.state == .queued || $0.state == .running }) {
        if Date() > end { Issue.record("jobs did not finish"); return }
        try await Task.sleep(for: .milliseconds(20))
    }
}

@MainActor @Test func convertsNextToOriginal() async throws {
    let dir = tmpDir(), input = dir.appendingPathComponent("photo.png")
    makeImage(input, type: .png, width: 8, height: 8)
    let q = JobQueue(registry: Registry([ImageConverter(binDir: binDir)]))
    q.add([input], format: .jpeg)
    try await waitUntilFinished(q)
    #expect(q.jobs.first?.state == .done(dir.appendingPathComponent("photo.jpg")))
}

@MainActor @Test func manyFilesSameOutputNameAllKept() async throws {
    // a.png and a.heic both want a.jpg.
    let dir = tmpDir()
    let inputs = [dir.appendingPathComponent("a.png"), dir.appendingPathComponent("a.heic")]
    makeImage(inputs[0], type: .png, width: 8, height: 8)
    makeImage(inputs[1], type: .heic, width: 8, height: 8)
    let q = JobQueue(registry: Registry([ImageConverter(binDir: binDir)]))
    q.add(inputs, format: .jpeg)
    try await waitUntilFinished(q)
    let names = q.jobs.compactMap { if case .done(let u) = $0.state { u.lastPathComponent } else { nil } }
    #expect(Set(names) == ["a.jpg", "a 2.jpg"])
}

@MainActor @Test func readOnlyFolderFailsCleanly() async throws {
    let dir = tmpDir(), input = dir.appendingPathComponent("p.png")
    makeImage(input, type: .png, width: 8, height: 8)
    try FileManager.default.setAttributes([.posixPermissions: 0o555], ofItemAtPath: dir.path)
    defer { try? FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: dir.path) }
    let q = JobQueue(registry: Registry([ImageConverter(binDir: binDir)]))
    q.add([input], format: .jpeg)
    try await waitUntilFinished(q)
    guard case .failed(let msg) = q.jobs.first?.state else { Issue.record("expected failure"); return }
    #expect(msg.contains("Couldn't save"))
    #expect(try FileManager.default.contentsOfDirectory(atPath: dir.path) == ["p.png"])
}

@MainActor @Test func unsupportedFileFailsWithMessage() async throws {
    let dir = tmpDir(), input = dir.appendingPathComponent("notes.txt")
    write("hi", to: input)
    let q = JobQueue(registry: Registry([ImageConverter(binDir: binDir)]))
    q.add([input], format: .jpeg)
    try await waitUntilFinished(q)
    #expect(q.jobs.first?.state == .failed("Can't convert notes.txt to JPG"))
}

@MainActor @Test func neverMoreThanMaxRunning() async throws {
    let dir = tmpDir()
    let inputs = (0..<6).map { i -> URL in
        let u = dir.appendingPathComponent("i\(i).png"); makeImage(u, type: .png, width: 400, height: 400); return u
    }
    let q = JobQueue(registry: Registry([ImageConverter(binDir: binDir)]), maxRunning: 2)
    q.add(inputs, format: .webp)
    var peak = 0
    while q.jobs.contains(where: { $0.state == .queued || $0.state == .running }) {
        peak = max(peak, q.jobs.filter { $0.state == .running }.count)
        try await Task.sleep(for: .milliseconds(5))
    }
    #expect(peak <= 2)
    #expect(q.jobs.allSatisfy { if case .done = $0.state { true } else { false } })
}
