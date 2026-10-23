import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

extension Format {
    public static let compress = Format(name: "Compress", type: .item, ext: "")
    public static let halfSize = Format(name: "Resize 50%", type: .item, ext: "")
}

/// Same-format image tools: re-encode smaller, or halve the pixel size.
public struct ImageToolConverter: Converter {
    public init() {}

    static let writable = Set(CGImageDestinationCopyTypeIdentifiers() as! [String])

    public func outputs(for input: UTType) -> [Format] {
        guard input.conforms(to: .image), ImageConverter.readable.contains(input.identifier),
              Self.writable.contains(input.identifier) else { return [] }
        return [.compress, .halfSize]
    }

    public func suggestedName(input: URL, format: Format) -> String {
        let suffix = format == .compress ? " (compressed)" : " (50%)"
        return input.deletingPathExtension().lastPathComponent + suffix + "." + input.pathExtension
    }

    public func convert(input: URL, to format: Format, output: URL) async throws {
        guard let src = CGImageSourceCreateWithURL(input as CFURL, nil), CGImageSourceGetCount(src) > 0,
              let type = CGImageSourceGetType(src)
        else { throw TangeloError("Can't read \(input.lastPathComponent) as an image") }
        guard let dst = CGImageDestinationCreateWithURL(output as CFURL, type, 1, nil)
        else { throw TangeloError("This Mac can't write \(type)") }

        if format == .compress {
            CGImageDestinationAddImageFromSource(dst, src, 0,
                [kCGImageDestinationLossyCompressionQuality: 0.6] as CFDictionary)
        } else {
            let p = CGImageSourceCopyPropertiesAtIndex(src, 0, nil) as? [CFString: Any] ?? [:]
            let side = max(p[kCGImagePropertyPixelWidth] as? Int ?? 0, p[kCGImagePropertyPixelHeight] as? Int ?? 0)
            CGImageDestinationAddImage(dst, try uprightImage(src, maxSide: side / 2),
                [kCGImageDestinationLossyCompressionQuality: 0.85] as CFDictionary)
        }
        guard CGImageDestinationFinalize(dst) else { throw TangeloError("Couldn't write \(output.lastPathComponent)") }
        if format == .compress, byteCount(of: output) >= byteCount(of: input) {
            throw TangeloError("\(input.lastPathComponent) is already as small as it gets — nothing saved")
        }
    }
}
