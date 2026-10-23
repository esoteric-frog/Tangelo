import Foundation

public enum ToolRunner {
    /// Run a bundled tool. Throws with the tool's last stderr lines on failure.
    public static func run(_ tool: URL, _ args: [String], timeout: TimeInterval = 300) async throws {
        let name = tool.lastPathComponent
        guard FileManager.default.isExecutableFile(atPath: tool.path) else {
            throw TangeloError("Tangelo is missing \(name) — rebuild with scripts/make-app.sh")
        }
        let process = Process()
        process.executableURL = tool
        process.arguments = args
        process.standardOutput = FileHandle.nullDevice
        let errPipe = Pipe()
        process.standardError = errPipe
        try process.run()
        // Drain stderr concurrently so a chatty tool can't block on a full pipe.
        let errData = Task.detached { errPipe.fileHandleForReading.readDataToEndOfFile() }

        let deadline = Date().addingTimeInterval(timeout)
        do {
            while process.isRunning {
                if Date() > deadline {
                    process.terminate()
                    throw TangeloError("\(name) stopped: it took longer than \(Int(timeout)) seconds")
                }
                try await Task.sleep(for: .milliseconds(50))  // ponytail: polling; fine for a handful of jobs
            }
        } catch {
            if process.isRunning { process.terminate() }
            throw error
        }
        let stderr = String(decoding: await errData.value.suffix(600), as: UTF8.self)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard process.terminationStatus == 0 else {
            throw TangeloError("\(name) failed (exit \(process.terminationStatus)): \(stderr)")
        }
    }
}
