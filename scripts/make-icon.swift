// Draws Resources/AppIcon.icns: glossy tangelo segments (same rounded, separated
// segments as the wheel), no peel, on a soft white rounded square. Run: swift scripts/make-icon.swift
import AppKit

func color(_ hex: UInt32) -> CGColor {
    CGColor(srgbRed: CGFloat(hex >> 16 & 255) / 255, green: CGFloat(hex >> 8 & 255) / 255,
            blue: CGFloat(hex & 255) / 255, alpha: 1)
}

func segment(_ i: Int, _ n: Int, _ c: CGPoint, inner: CGFloat, outer: CGFloat, gap: CGFloat, corner: CGFloat) -> CGPath {
    let step = 2 * Double.pi / Double(n), mid = step * Double(i), d = gap / 2 + corner
    let ri = inner + corner, ro = outer - corner
    func pt(_ r: CGFloat, _ a: Double) -> CGPoint { CGPoint(x: c.x + r * sin(a), y: c.y + r * cos(a)) }
    func span(_ r: CGFloat) -> (Double, Double) { let o = asin(Double(d / r)); return (mid - step / 2 + o, mid + step / 2 - o) }
    let (o0, o1) = span(ro), (i0, i1) = span(ri)
    let p = CGMutablePath()
    p.move(to: pt(ro, o0))
    for k in 1...64 { p.addLine(to: pt(ro, o0 + (o1 - o0) * Double(k) / 64)) }
    for k in 0...4 { p.addLine(to: pt(ri, i1 - (i1 - i0) * Double(k) / 4)) }  // few points: no kinks at the tips
    p.closeSubpath()
    return p.union(p.copy(strokingWithWidth: 2 * corner, lineCap: .round, lineJoin: .round, miterLimit: 1))
}

func draw(_ px: Int) -> CGImage {
    let s = CGFloat(px) / 1024
    let ctx = CGContext(data: nil, width: px, height: px, bitsPerComponent: 8, bytesPerRow: 0,
                        space: CGColorSpace(name: CGColorSpace.sRGB)!,
                        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    ctx.scaleBy(x: s, y: s)
    // macOS icon grid: 824 pt rounded square centred in 1024.
    let tile = CGPath(roundedRect: CGRect(x: 100, y: 100, width: 824, height: 824),
                      cornerWidth: 185, cornerHeight: 185, transform: nil)
    let sRGB = CGColorSpace(name: CGColorSpace.sRGB)!
    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -10), blur: 24, color: CGColor(gray: 0, alpha: 0.25))
    ctx.addPath(tile); ctx.setFillColor(color(0xF4F2F0)); ctx.fillPath()
    ctx.restoreGState()
    ctx.saveGState()  // soft top-to-bottom sheen on the tile
    ctx.addPath(tile); ctx.clip()
    ctx.drawLinearGradient(CGGradient(colorsSpace: sRGB, colors: [color(0xFFFFFF), color(0xE9E6E3)] as CFArray,
                                      locations: [0, 1])!,
                           start: CGPoint(x: 512, y: 924), end: CGPoint(x: 512, y: 100), options: [])
    ctx.restoreGState()
    // Tangelo colours: deeper red-orange than a tangerine, lighter toward the bottom.
    let c = CGPoint(x: 512, y: 512)
    let n = 7
    for i in 0..<n {
        let seg = segment(i, n, c, inner: 70, outer: 300, gap: 18, corner: 14)
        ctx.saveGState()
        ctx.setShadow(offset: CGSize(width: 0, height: -6), blur: 14, color: CGColor(srgbRed: 0.75, green: 0.2, blue: 0, alpha: 0.35))
        ctx.addPath(seg); ctx.setFillColor(color(0xF0552A)); ctx.fillPath()
        ctx.restoreGState()
        ctx.saveGState()
        ctx.addPath(seg); ctx.clip()
        ctx.drawLinearGradient(CGGradient(colorsSpace: sRGB, colors: [color(0xF2492A), color(0xFF9A4D)] as CFArray,
                                          locations: [0, 1])!,
                               start: CGPoint(x: 512, y: 842), end: CGPoint(x: 512, y: 182), options: [])
        ctx.addPath(seg)  // glassy rim
        ctx.setStrokeColor(CGColor(srgbRed: 1, green: 0.85, blue: 0.7, alpha: 0.7)); ctx.setLineWidth(10); ctx.strokePath()
        ctx.restoreGState()
    }
    return ctx.makeImage()!
}

let root = URL(fileURLWithPath: CommandLine.arguments[0]).deletingLastPathComponent().deletingLastPathComponent()
let set = FileManager.default.temporaryDirectory.appendingPathComponent("AppIcon.iconset")
try? FileManager.default.removeItem(at: set)
try FileManager.default.createDirectory(at: set, withIntermediateDirectories: true)
for base in [16, 32, 128, 256, 512] {
    for scale in [1, 2] {
        let name = "icon_\(base)x\(base)" + (scale == 2 ? "@2x" : "") + ".png"
        let rep = NSBitmapImageRep(cgImage: draw(base * scale))
        try rep.representation(using: .png, properties: [:])!.write(to: set.appendingPathComponent(name))
    }
}
let out = root.appendingPathComponent("Resources/AppIcon.icns")
let p = Process()
p.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
p.arguments = ["-c", "icns", set.path, "-o", out.path]
try p.run(); p.waitUntilExit()
print(p.terminationStatus == 0 ? "Wrote \(out.path)" : "iconutil failed")
