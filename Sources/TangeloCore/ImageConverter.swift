import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

public struct ImageConverter: Converter {
    let binDir: URL
    public init(binDir: URL) { self.binDir = binDir }

    static let readable = Set(CGImageSourceCopyTypeIdentifiers() as! [String])
    static let all: [Format] = [.jpeg, .png, .heic, .avif, .webp, .tiff]

    public func outputs(for input: UTType) -> [Format] {
        guard input.conforms(to: .image), Self.readable.contains(input.identifier) else { return [] }
        return Self.all.filter { !input.conforms(to: $0.type) }
    }

    public func convert(input: URL, to format: Format, output: URL) async throws {
        guard let src = CGImageSourceCreateWithURL(input as CFURL, nil),
              CGImageSourceGetCount(src) > 0,
              CGImageSourceCreateImageAtIndex(src, 0, nil) != nil
        else { throw TangeloError("Can't read \(input.lastPathComponent) as an image") }

        switch format {
        case .webp:
            // cwebp ignores EXIF rotation, so hand it an already-upright PNG.
            let tmp = output.deletingLastPathComponent().appendingPathComponent("upright-\(UUID().uuidString).png")
            defer { try? FileManager.default.removeItem(at: tmp) }
            try write(upright(src), properties: [:], type: .png, to: tmp)
            try await ToolRunner.run(binDir.appendingPathComponent("cwebp"),
                                     ["-quiet", "-q", "85", "-metadata", "icc", tmp.path, "-o", output.path])
        case .jpeg where hasAlpha(src):
            // JPEG has no transparency; flatten onto white instead of ImageIO's black.
            try write(onWhite(upright(src)), properties: [kCGImageDestinationLossyCompressionQuality: 0.85],
                      type: .jpeg, to: output)
        default:
            guard let dst = CGImageDestinationCreateWithURL(output as CFURL, format.type.identifier as CFString, 1, nil)
            else { throw TangeloError("This Mac can't write \(format.name)") }
            CGImageDestinationAddImageFromSource(dst, src, 0,
                [kCGImageDestinationLossyCompressionQuality: 0.85] as CFDictionary)  // keeps EXIF + orientation
            guard CGImageDestinationFinalize(dst) else { throw TangeloError("Couldn't write \(format.name)") }
        }
    }

    func upright(_ src: CGImageSource) throws -> CGImage { try uprightImage(src, maxSide: nil) }

    func hasAlpha(_ src: CGImageSource) -> Bool {
        (CGImageSourceCopyPropertiesAtIndex(src, 0, nil) as? [CFString: Any])?[kCGImagePropertyHasAlpha] as? Bool ?? false
    }

    func onWhite(_ img: CGImage) throws -> CGImage {
        guard let ctx = CGContext(data: nil, width: img.width, height: img.height, bitsPerComponent: 8, bytesPerRow: 0,
                                  space: CGColorSpace(name: CGColorSpace.sRGB)!,
                                  bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)
        else { throw TangeloError("Out of memory flattening the image") }
        let rect = CGRect(x: 0, y: 0, width: img.width, height: img.height)
        ctx.setFillColor(red: 1, green: 1, blue: 1, alpha: 1)
        ctx.fill(rect)
        ctx.draw(img, in: rect)
        return ctx.makeImage()!
    }

    func write(_ img: CGImage, properties: [CFString: Any], type: UTType, to url: URL) throws {
        guard let dst = CGImageDestinationCreateWithURL(url as CFURL, type.identifier as CFString, 1, nil)
        else { throw TangeloError("This Mac can't write \(type.identifier)") }
        CGImageDestinationAddImage(dst, img, properties as CFDictionary)
        guard CGImageDestinationFinalize(dst) else { throw TangeloError("Couldn't write \(url.lastPathComponent)") }
    }
}

/// Image with EXIF orientation applied to the pixels; `maxSide` nil = full size.
func uprightImage(_ src: CGImageSource, maxSide: Int?) throws -> CGImage {
    let p = CGImageSourceCopyPropertiesAtIndex(src, 0, nil) as? [CFString: Any] ?? [:]
    let full = max(p[kCGImagePropertyPixelWidth] as? Int ?? 0, p[kCGImagePropertyPixelHeight] as? Int ?? 0)
    let opts: [CFString: Any] = [
        kCGImageSourceCreateThumbnailFromImageAlways: true,
        kCGImageSourceCreateThumbnailWithTransform: true,
        kCGImageSourceThumbnailMaxPixelSize: max(1, maxSide ?? full),
    ]
    guard let img = CGImageSourceCreateThumbnailAtIndex(src, 0, opts as CFDictionary)
    else { throw TangeloError("Couldn't decode the image") }
    return img
}

func byteCount(of url: URL) -> Int {
    (try? FileManager.default.attributesOfItem(atPath: url.path)[.size] as? Int) ?? 0
}
