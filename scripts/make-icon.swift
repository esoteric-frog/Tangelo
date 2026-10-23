// Draws Resources/AppIcon.icns: a minimal cut tangerine (same rounded, separated
// segments as the wheel) on a warm white rounded square. Run: swift scripts/make-icon.swift
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
    for k in 0...64 { p.addLine(to: pt(ri, i1 - (i1 - i0) * Double(k) / 64)) }
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
    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -10), blur: 24, color: CGColor(gray: 0, alpha: 0.25))
    ctx.addPath(tile); ctx.setFillColor(color(0xFFF8EF)); ctx.fillPath()
    ctx.restoreGState()
    let c = CGPoint(x: 512, y: 512)
    ctx.setFillColor(color(0xF57C1F))  // peel
    ctx.fillEllipse(in: CGRect(x: c.x - 300, y: c.y - 300, width: 600, height: 600))
    ctx.setFillColor(color(0xFFF1DC))  // pith
    ctx.fillEllipse(in: CGRect(x: c.x - 262, y: c.y - 262, width: 524, height: 524))
    ctx.setFillColor(color(0xFFA23A))  // segments
    for i in 0..<8 {
        ctx.addPath(segment(i, 8, c, inner: 58, outer: 246, gap: 16, corner: 18))
        ctx.fillPath()
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
