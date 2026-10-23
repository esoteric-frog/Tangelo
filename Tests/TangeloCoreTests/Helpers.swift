import Foundation

func tmpDir() -> URL {
    let url = FileManager.default.temporaryDirectory
        .appendingPathComponent("tangelo-test-\(UUID().uuidString)")
    try! FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    return url
}

/// Package root/vendor/bin, found from this file's location.
let binDir = URL(fileURLWithPath: #filePath)
    .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
    .appendingPathComponent("vendor/bin")

func write(_ text: String, to url: URL) { try! text.write(to: url, atomically: true, encoding: .utf8) }
func read(_ url: URL) -> String { try! String(contentsOf: url, encoding: .utf8) }
