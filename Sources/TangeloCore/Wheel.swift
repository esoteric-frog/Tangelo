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
