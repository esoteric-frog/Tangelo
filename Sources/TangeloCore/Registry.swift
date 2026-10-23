import Foundation
import UniformTypeIdentifiers

public struct Registry: Sendable {
    public let converters: [any Converter]
    public init(_ converters: [any Converter]) { self.converters = converters }

    static func type(of file: URL) -> UTType? { UTType(filenameExtension: file.pathExtension.lowercased()) }

    /// Formats every file in `files` can become, in the first file's order.
    public func choices(for files: [URL]) -> [Format] {
        let perFile = files.map { file -> [Format] in
            guard let t = Self.type(of: file) else { return [] }
            return converters.flatMap { $0.outputs(for: t) }
        }
        guard let first = perFile.first else { return [] }
        return first.filter { f in perFile.allSatisfy { $0.contains(f) } }
    }

    public func converter(for file: URL, format: Format) -> (any Converter)? {
        guard let t = Self.type(of: file) else { return nil }
        return converters.first { $0.outputs(for: t).contains(format) }
    }
}
