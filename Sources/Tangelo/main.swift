import AppKit
import SwiftUI
import TangeloCore

/// Transparent view over the status-bar button that accepts file drops.
final class DropView: NSView {
    var onDrop: ([URL]) -> Void = { _ in }

    override init(frame: NSRect) {
        super.init(frame: frame)
        registerForDraggedTypes([.fileURL])
        autoresizingMask = [.width, .height]
    }
    required init?(coder: NSCoder) { fatalError() }

    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation { .copy }
    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        let urls = sender.draggingPasteboard.readObjects(forClasses: [NSURL.self],
            options: [.urlReadingFileURLsOnly: true]) as? [URL] ?? []
        guard !urls.isEmpty else { return false }
        onDrop(urls)
        return true
    }
    // Let clicks reach the button underneath.
    override func mouseDown(with event: NSEvent) { superview?.mouseDown(with: event) }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    let popover = NSPopover()
    let drop = DropState()
    lazy var registry = Registry([
        ImageConverter(binDir: Bundle.main.resourceURL!.appendingPathComponent("bin")),
        PDFShrinkConverter(),
    ])
    lazy var queue = JobQueue(registry: registry)

    func applicationDidFinishLaunching(_ note: Notification) {
        let button = statusItem.button!
        button.image = NSImage(systemSymbolName: "arrow.triangle.2.circlepath.circle.fill",
                               accessibilityDescription: "Tangelo")
        button.target = self
        button.action = #selector(toggle)
        let dropView = DropView(frame: button.bounds)
        dropView.onDrop = { [weak self] urls in self?.received(urls) }
        button.addSubview(dropView)

        popover.behavior = .transient
        popover.contentViewController = NSHostingController(rootView: PanelView(
            queue: queue, drop: drop,
            onPick: { [weak self] f in self?.pick(f) },
            onChooseFiles: { [weak self] in self?.chooseFiles() }))
    }

    func received(_ urls: [URL]) {
        drop.files = urls
        drop.choices = registry.choices(for: urls)
        show()
    }

    func pick(_ format: Format) {
        queue.add(drop.files, format: format)
        drop.files = []
        drop.choices = []
    }

    func chooseFiles() {
        popover.performClose(nil)
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = true
        NSApp.activate()
        if panel.runModal() == .OK { received(panel.urls) }
    }

    func show() {
        guard let button = statusItem.button else { return }
        if !popover.isShown { popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY) }
        NSApp.activate()
    }

    @objc func toggle() { popover.isShown ? popover.performClose(nil) : show() }
}

MainActor.assumeIsolated {  // top-level code runs on the main thread
    let app = NSApplication.shared
    let delegate = AppDelegate()
    app.delegate = delegate
    app.setActivationPolicy(.accessory)
    app.run()
}
