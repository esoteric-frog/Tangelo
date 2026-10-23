import Foundation
import UniformTypeIdentifiers

/// One output choice shown to the user.
public struct Format: Hashable, Sendable {
    public let name: String
    public let type: UTType
    public let ext: String

    public static let jpeg = Format(name: "JPG", type: .jpeg, ext: "jpg")
    public static let png = Format(name: "PNG", type: .png, ext: "png")
    public static let tiff = Format(name: "TIFF", type: .tiff, ext: "tiff")
    public static let heic = Format(name: "HEIC", type: .heic, ext: "heic")
    public static let avif = Format(name: "AVIF", type: UTType(filenameExtension: "avif")!, ext: "avif")
    public static let webp = Format(name: "WebP", type: .webP, ext: "webp")
    public static let smallPDF = Format(name: "Smaller PDF", type: .pdf, ext: "pdf")
}

/// One way of turning files of some types into some formats.
/// New formats (parts 2–5) are new conformers; nothing else changes.
public protocol Converter: Sendable {
    /// Formats this converter can make from `input`; empty = not handled.
    func outputs(for input: UTType) -> [Format]
    func suggestedName(input: URL, format: Format) -> String
    /// Write the result to `output` (a temp path). Throw on failure.
    func convert(input: URL, to format: Format, output: URL) async throws
}

extension Converter {
    public func suggestedName(input: URL, format: Format) -> String {
        input.deletingPathExtension().lastPathComponent + "." + format.ext
    }
}

/// An error whose message is shown to the user as-is.
public struct TangeloError: LocalizedError, Equatable {
    public let message: String
    public init(_ message: String) { self.message = message }
    public var errorDescription: String? { message }
}
