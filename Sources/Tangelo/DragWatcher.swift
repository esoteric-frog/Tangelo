import AppKit
import TangeloCore

/// Sees file drags from any app and ⌃/⌘/⌥ held during them, with no permissions:
/// it only polls mouse-button state, modifier state and the drag pasteboard.
@MainActor
final class DragWatcher {
    var onHold: (WheelKey, [URL]) -> Void = { _, _ in }
    var onRelease: () -> Void = {}
    var onDragEnd: () -> Void = {}

    private var timer: Timer?
    private var mouseWasDown = false
    private var startCount = 0
    private var dragging = false
    private var holds = HoldDetector()

    func start() {
        // ponytail: 30 Hz poll of three cheap class properties; event taps would need Accessibility.
        let t = Timer(timeInterval: 1.0 / 30, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.tick() }
        }
        RunLoop.main.add(t, forMode: .common)
        timer = t
    }

    private func tick() {
        let down = NSEvent.pressedMouseButtons & 1 == 1
        let pb = NSPasteboard(name: .drag)
        if down && !mouseWasDown { startCount = pb.changeCount; dragging = false; holds.reset() }
        if !down && mouseWasDown && dragging { dragging = false; onDragEnd() }
        mouseWasDown = down
        guard down else { return }
        if !dragging, pb.changeCount != startCount, !Self.files(pb).isEmpty { dragging = true }
        guard dragging else { return }
        let flags = NSEvent.modifierFlags
        var keys = Set<WheelKey>()
        if flags.contains(.control) { keys.insert(.control) }
        if flags.contains(.command) { keys.insert(.command) }
        if flags.contains(.option) { keys.insert(.option) }
        switch holds.update(keys, at: Date()) {
        case .open(let key): onHold(key, Self.files(pb))
        case .close: onRelease()
        case nil: break
        }
    }

    static func files(_ pb: NSPasteboard) -> [URL] {
        pb.readObjects(forClasses: [NSURL.self], options: [.urlReadingFileURLsOnly: true]) as? [URL] ?? []
    }
}
