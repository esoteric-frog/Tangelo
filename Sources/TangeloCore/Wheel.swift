import CoreGraphics
import Foundation
import UniformTypeIdentifiers

public enum WheelKey: Sendable, Hashable { case control, command, option }

public enum WheelKind: String, Sendable, CaseIterable {
    case conversion, tools, actions

    public static func opened(by key: WheelKey) -> WheelKind {
        switch key { case .control: .conversion; case .command: .tools; case .option: .actions }
    }

    public var title: String {
        switch self { case .conversion: "Convert"; case .tools: "Tools"; case .actions: "Actions" }
    }
}

/// Turns samples of "which wheel keys are down" into taps:
/// one key pressed alone and released within `maxTap`.
public struct TapDetector: Sendable {
    public var maxTap: TimeInterval
    private var candidate: (key: WheelKey, at: Date)?
    private var previous: Set<WheelKey> = []

    public init(maxTap: TimeInterval = 0.5) { self.maxTap = maxTap }

    public mutating func update(_ down: Set<WheelKey>, at now: Date) -> WheelKey? {
        defer { previous = down }
        if down.count > 1 { candidate = nil; return nil }
        if let key = down.first, !previous.contains(key) {
            candidate = previous.isEmpty ? (key, now) : nil
            return nil
        }
        if down.isEmpty, let c = candidate {
            candidate = nil
            return previous == [c.key] && now.timeIntervalSince(c.at) <= maxTap ? c.key : nil
        }
        return nil
    }

    public mutating func reset() { candidate = nil; previous = [] }
}

public enum WheelGeometry {
    /// Slice under `point` (slice 0 centred at 12 o'clock, clockwise; y-up coordinates),
    /// or nil inside the dead zone.
    public static func slice(at point: CGPoint, center: CGPoint, count: Int, deadZone: CGFloat) -> Int? {
        guard count > 0 else { return nil }
        let dx = Double(point.x - center.x), dy = Double(point.y - center.y)
        guard hypot(dx, dy) >= Double(deadZone) else { return nil }
        let step = 2 * Double.pi / Double(count)
        var a = (atan2(dx, dy) + step / 2).truncatingRemainder(dividingBy: 2 * .pi)  // 0 = up, clockwise
        if a < 0 { a += 2 * .pi }
        return Int(a / step) % count
    }

    /// Centre angle of slice `i` in radians; 0 = up, clockwise.
    public static func angle(of i: Int, count: Int) -> Double { 2 * .pi * Double(i) / Double(count) }

    /// Outline of slice `i` like a tangerine segment: straight seams `gap` wide between
    /// neighbours and every corner rounded by `corner`. y-up coordinates.
    public static func slicePath(index i: Int, count: Int, center c: CGPoint,
                                 inner: CGFloat, outer: CGFloat, gap: CGFloat, corner: CGFloat) -> CGPath {
        func pt(_ r: CGFloat, _ a: Double) -> CGPoint { CGPoint(x: c.x + r * sin(a), y: c.y + r * cos(a)) }
        let path = CGMutablePath()
        if count == 1 {  // one choice: whole ring, inner circle wound the other way to cut the hole
            path.addArc(center: c, radius: outer, startAngle: 0, endAngle: 2 * .pi, clockwise: false)
            path.addArc(center: c, radius: inner, startAngle: 0, endAngle: -2 * .pi, clockwise: true)
            return path
        }
        // Shrink by `corner`, then grow back with a round stroke: exact rounded corners.
        let ri = inner + corner, ro = outer - corner, d = gap / 2 + corner
        let step = 2 * Double.pi / Double(count), mid = angle(of: i, count: count)
        func span(_ r: CGFloat) -> (Double, Double) {
            let off = asin(min(1, Double(d / r)))  // keeps the seam edges parallel, not wedge-shaped
            return (mid - step / 2 + off, mid + step / 2 - off)
        }
        let (o0, o1) = span(ro), (i0, i1) = span(ri)
        // ponytail: tiny slices (many choices, small ring) vanish; shrink `corner` if formats ever pass ~16.
        guard o1 > o0, i1 > i0 else { return path }
        let n = 48
        path.move(to: pt(ro, o0))
        for k in 1...n { path.addLine(to: pt(ro, o0 + (o1 - o0) * Double(k) / Double(n))) }
        for k in 0...n { path.addLine(to: pt(ri, i1 - (i1 - i0) * Double(k) / Double(n))) }
        path.closeSubpath()
        return path.union(path.copy(strokingWithWidth: 2 * corner, lineCap: .round, lineJoin: .round, miterLimit: 1))
    }
}

public enum FileAction: String, CaseIterable, Sendable {
    case airDrop, copyFiles, copyPaths, terminal, showInFinder

    public var title: String {
        switch self {
        case .airDrop: "AirDrop"
        case .copyFiles: "Copy Files"
        case .copyPaths: "Copy Paths"
        case .terminal: "Open in Terminal"
        case .showInFinder: "Show in Finder"
        }
    }

    public var symbol: String {
        switch self {
        case .airDrop: "dot.radiowaves.left.and.right"
        case .copyFiles: "doc.on.doc"
        case .copyPaths: "link"
        case .terminal: "terminal"
        case .showInFinder: "folder"
        }
    }

    public static func paths(_ files: [URL]) -> String { files.map(\.path).joined(separator: "\n") }

    /// The first item if it is a folder, else the folder containing it.
    public static func terminalFolder(for files: [URL]) -> URL? {
        guard let first = files.first else { return nil }
        let isDir = (try? first.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false
        return isDir ? first : first.deletingLastPathComponent()
    }
}

public enum WheelChoice: Hashable, Sendable {
    case format(Format)
    case action(FileAction)

    public var title: String {
        switch self { case .format(let f): f.name; case .action(let a): a.title }
    }

    public var symbol: String {
        switch self {
        case .action(let a): a.symbol
        case .format(let f):
            switch f.name {
            case "Compress": "arrow.down.right.and.arrow.up.left"
            case "Resize 50%": "aspectratio"
            default: f.type.conforms(to: .pdf) ? "doc" : "photo"
            }
        }
    }
}

public struct WheelMenus: Sendable {
    public let conversion: Registry
    public let tools: Registry

    public init(conversion: Registry, tools: Registry) {
        self.conversion = conversion
        self.tools = tools
    }

    public func choices(_ kind: WheelKind, for files: [URL]) -> [WheelChoice] {
        switch kind {
        case .conversion: conversion.choices(for: files).map(WheelChoice.format)
        case .tools: tools.choices(for: files).map(WheelChoice.format)
        case .actions: files.isEmpty ? [] : FileAction.allCases.map(WheelChoice.action)
        }
    }
}
