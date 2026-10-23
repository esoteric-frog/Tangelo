import Combine
import Foundation

public enum JobState: Equatable, Sendable {
    case queued, running, done(URL), failed(String)
}

public struct Job: Identifiable, Sendable {
    public let id = UUID()
    public let input: URL
    public let format: Format
    public var state: JobState = .queued
}

@MainActor
public final class JobQueue: ObservableObject {
    @Published public private(set) var jobs: [Job] = []
    let registry: Registry
    let maxRunning: Int

    public init(registry: Registry, maxRunning: Int = 2) {
        self.registry = registry
        self.maxRunning = maxRunning
    }

    public func add(_ files: [URL], format: Format) {
        jobs += files.map { Job(input: $0, format: format) }
        pump()
    }

    public func clearFinished() {
        jobs.removeAll { if case .done = $0.state { true } else if case .failed = $0.state { true } else { false } }
    }

    private func pump() {
        while jobs.filter({ $0.state == .running }).count < maxRunning,
              let i = jobs.firstIndex(where: { $0.state == .queued }) {
            jobs[i].state = .running
            let job = jobs[i]
            let converter = registry.converter(for: job.input, format: job.format)
            Task {
                let result = await Self.perform(job, converter)
                if let j = jobs.firstIndex(where: { $0.id == job.id }) { jobs[j].state = result }
                pump()
            }
        }
    }

    /// Convert into a private temp folder, then move next to the original. Temp is always removed.
    nonisolated static func perform(_ job: Job, _ converter: (any Converter)?) async -> JobState {
        guard let converter else {
            return .failed("Can't convert \(job.input.lastPathComponent) to \(job.format.name)")
        }
        let fm = FileManager.default
        let work = fm.temporaryDirectory.appendingPathComponent("tangelo-\(job.id.uuidString)")
        defer { try? fm.removeItem(at: work) }
        do {
            try fm.createDirectory(at: work, withIntermediateDirectories: true)
            let name = converter.suggestedName(input: job.input, format: job.format)
            let temp = work.appendingPathComponent(name)
            try await converter.convert(input: job.input, to: job.format, output: temp)
            return .done(try OutputNamer.place(temp, in: job.input.deletingLastPathComponent(), name: name))
        } catch {
            return .failed(error.localizedDescription)
        }
    }
}
