import Foundation
import Testing
@testable import TangeloCore

@Test func placesUnderRequestedName() throws {
    let dir = tmpDir(), temp = tmpDir().appendingPathComponent("x")
    write("new", to: temp)
    let out = try OutputNamer.place(temp, in: dir, name: "photo.jpg")
    #expect(out.lastPathComponent == "photo.jpg")
    #expect(read(out) == "new")
    #expect(!FileManager.default.fileExists(atPath: temp.path))
}

@Test func neverOverwrites() throws {
    let dir = tmpDir()
    write("old", to: dir.appendingPathComponent("photo.jpg"))
    write("old2", to: dir.appendingPathComponent("photo 2.jpg"))
    let temp = tmpDir().appendingPathComponent("x"); write("new", to: temp)
    let out = try OutputNamer.place(temp, in: dir, name: "photo.jpg")
    #expect(out.lastPathComponent == "photo 3.jpg")
    #expect(read(dir.appendingPathComponent("photo.jpg")) == "old")
    #expect(read(dir.appendingPathComponent("photo 2.jpg")) == "old2")
}

@Test func concurrentSameNameKeepsBoth() async throws {
    let dir = tmpDir()
    let temps = (0..<8).map { i -> URL in
        let t = tmpDir().appendingPathComponent("x"); write("\(i)", to: t); return t
    }
    let outs = try await withThrowingTaskGroup(of: URL.self) { g in
        for t in temps { g.addTask { try OutputNamer.place(t, in: dir, name: "a.png") } }
        return try await g.reduce(into: [URL]()) { $0.append($1) }
    }
    #expect(Set(outs.map(\.lastPathComponent)).count == 8)
    #expect(Set(outs.map(read)) == Set((0..<8).map(String.init)))
}

@Test func readOnlyFolderThrowsReadableError() throws {
    let dir = tmpDir()
    try FileManager.default.setAttributes([.posixPermissions: 0o555], ofItemAtPath: dir.path)
    defer { try? FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: dir.path) }
    let temp = tmpDir().appendingPathComponent("x"); write("new", to: temp)
    #expect(throws: TangeloError.self) { try OutputNamer.place(temp, in: dir, name: "a.png") }
}
