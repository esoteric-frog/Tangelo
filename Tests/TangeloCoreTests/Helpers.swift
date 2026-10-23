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

import CoreGraphics
import ImageIO
import UniformTypeIdentifiers

/// Solid red image; `alpha: true` makes it fully transparent instead.
func makeImage(_ url: URL, type: UTType, width: Int, height: Int, alpha: Bool = false, orientation: Int = 1) {
    let ctx = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
                        space: CGColorSpace(name: CGColorSpace.sRGB)!,
                        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    if !alpha { ctx.setFillColor(red: 1, green: 0, blue: 0, alpha: 1); ctx.fill(CGRect(x: 0, y: 0, width: width, height: height)) }
    let dst = CGImageDestinationCreateWithURL(url as CFURL, type.identifier as CFString, 1, nil)!
    CGImageDestinationAddImage(dst, ctx.makeImage()!, [kCGImagePropertyOrientation: orientation] as CFDictionary)
    precondition(CGImageDestinationFinalize(dst))
}

/// Type identifier and *displayed* (orientation-applied) size.
func imageInfo(_ url: URL) -> (type: String, width: Int, height: Int)? {
    guard let src = CGImageSourceCreateWithURL(url as CFURL, nil),
          let type = CGImageSourceGetType(src) as String?,
          let p = CGImageSourceCopyPropertiesAtIndex(src, 0, nil) as? [CFString: Any],
          let w = p[kCGImagePropertyPixelWidth] as? Int, let h = p[kCGImagePropertyPixelHeight] as? Int
    else { return nil }
    let o = p[kCGImagePropertyOrientation] as? Int ?? 1
    return (type, o >= 5 ? h : w, o >= 5 ? w : h)
}

func pixel(_ url: URL, x: Int, y: Int) -> (r: UInt8, g: UInt8, b: UInt8) {
    let src = CGImageSourceCreateWithURL(url as CFURL, nil)!
    let img = CGImageSourceCreateImageAtIndex(src, 0, nil)!
    var px = [UInt8](repeating: 0, count: 4)
    let ctx = CGContext(data: &px, width: 1, height: 1, bitsPerComponent: 8, bytesPerRow: 4,
                        space: CGColorSpace(name: CGColorSpace.sRGB)!,
                        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    ctx.draw(img, in: CGRect(x: -x, y: -(img.height - 1 - y), width: img.width, height: img.height))
    return (px[0], px[1], px[2])
}
