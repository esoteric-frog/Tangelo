import AppKit
import SwiftUI
import TangeloCore

final class WheelModel: ObservableObject {
    @Published var kind: WheelKind = .conversion
    @Published var choices: [WheelChoice] = []
    @Published var highlighted: Int?
}

/// Borderless glass wheel centred on the pointer; the drop view on top picks the slice.
@MainActor
final class WheelController {
    static let size: CGFloat = 340
    static let deadZone: CGFloat = 50

    var onChoose: (WheelChoice, [URL]) -> Void = { _, _ in }
    let model = WheelModel()
    private var panel: NSPanel?
    private var closeWork: DispatchWorkItem?

    func open(kind: WheelKind, choices: [WheelChoice], at point: NSPoint) {
        closeWork?.cancel()
        model.kind = kind
        model.choices = choices
        model.highlighted = nil
        let s = Self.size
        let frame = NSRect(x: point.x - s / 2, y: point.y - s / 2, width: s, height: s)
        let panel = self.panel ?? makePanel()
        panel.setFrame(frame, display: true)
        panel.orderFrontRegardless()
        self.panel = panel
    }

    /// Close shortly after the drag ends: mouse-up can be seen before AppKit delivers the drop.
    func closeSoon() {
        closeWork?.cancel()
        let work = DispatchWorkItem { [weak self] in self?.panel?.orderOut(nil) }
        closeWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4, execute: work)
    }

    private func makePanel() -> NSPanel {
        let s = Self.size
        let panel = NSPanel(contentRect: NSRect(x: 0, y: 0, width: s, height: s),
                            styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.level = .popUpMenu
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]

        let root = NSView(frame: NSRect(x: 0, y: 0, width: s, height: s))
        let graphic = NSHostingView(rootView: WheelGraphic(model: model))
        graphic.frame = root.bounds
        graphic.autoresizingMask = [.width, .height]
        root.addSubview(graphic)
        let drop = WheelDropView(frame: root.bounds, model: model)
        drop.onDrop = { [weak self] choice, urls in
            self?.onChoose(choice, urls)
            self?.panel?.orderOut(nil)
        }
        root.addSubview(drop)
        panel.contentView = root
        return panel
    }
}

final class WheelDropView: NSView {
    let model: WheelModel
    var onDrop: (WheelChoice, [URL]) -> Void = { _, _ in }
    private let tick: NSSound? = {
        let s = NSSound(named: "Tink")
        s?.volume = 0.25
        return s
    }()

    init(frame: NSRect, model: WheelModel) {
        self.model = model
        super.init(frame: frame)
        autoresizingMask = [.width, .height]
        registerForDraggedTypes([.fileURL])
    }
    required init?(coder: NSCoder) { fatalError() }

    private func slice(_ sender: NSDraggingInfo) -> Int? {
        let p = convert(sender.draggingLocation, from: nil)
        let center = CGPoint(x: bounds.midX, y: bounds.midY)
        guard hypot(p.x - center.x, p.y - center.y) <= bounds.width / 2 else { return nil }
        return WheelGeometry.slice(at: p, center: center, count: model.choices.count, deadZone: WheelController.deadZone)
    }

    private func track(_ sender: NSDraggingInfo) -> NSDragOperation {
        let i = slice(sender)
        if i != model.highlighted {
            model.highlighted = i
            if i != nil {
                NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .now)
                tick?.stop()
                tick?.play()
            }
        }
        return i == nil ? [] : .copy
    }

    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation { track(sender) }
    override func draggingUpdated(_ sender: NSDraggingInfo) -> NSDragOperation { track(sender) }
    override func draggingExited(_ sender: NSDraggingInfo?) { model.highlighted = nil }

    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        guard let i = slice(sender), model.choices.indices.contains(i) else { return false }
        let urls = sender.draggingPasteboard.readObjects(forClasses: [NSURL.self],
            options: [.urlReadingFileURLsOnly: true]) as? [URL] ?? []
        guard !urls.isEmpty else { return false }
        onDrop(model.choices[i], urls)
        return true
    }
}

struct SliceShape: Shape {
    let index: Int, count: Int
    let inner: CGFloat, outer: CGFloat

    func path(in rect: CGRect) -> Path {
        let c = CGPoint(x: rect.midX, y: rect.midY)
        let step = 2 * Double.pi / Double(count)
        let gap = count > 1 ? 0.012 : 0
        let a0 = WheelGeometry.angle(of: index, count: count) - step / 2 + gap
        let a1 = a0 + step - 2 * gap
        func pt(_ r: CGFloat, _ a: Double) -> CGPoint { CGPoint(x: c.x + r * sin(a), y: c.y - r * cos(a)) }  // y-down
        let n = 32
        var p = Path()
        p.move(to: pt(inner, a0))
        for s in 0...n { p.addLine(to: pt(outer, a0 + (a1 - a0) * Double(s) / Double(n))) }
        for s in (0...n).reversed() { p.addLine(to: pt(inner, a0 + (a1 - a0) * Double(s) / Double(n))) }
        p.closeSubpath()
        return p
    }
}

struct WheelGraphic: View {
    @ObservedObject var model: WheelModel

    var body: some View {
        GeometryReader { geo in
            let outer = min(geo.size.width, geo.size.height) / 2 - 8
            let inner = WheelController.deadZone
            let c = CGPoint(x: geo.size.width / 2, y: geo.size.height / 2)
            let n = model.choices.count
            ZStack {
                Circle().fill(.ultraThinMaterial).frame(width: outer * 2, height: outer * 2)
                    .overlay(Circle().stroke(.white.opacity(0.25), lineWidth: 1))
                ForEach(Array(model.choices.enumerated()), id: \.offset) { i, choice in
                    SliceShape(index: i, count: n, inner: inner, outer: outer)
                        .fill(model.highlighted == i ? Color.orange.opacity(0.9) : Color.primary.opacity(0.06))
                    let a = WheelGeometry.angle(of: i, count: n), mid = (inner + outer) / 2
                    VStack(spacing: 3) {
                        Image(systemName: choice.symbol).font(.system(size: 18, weight: .semibold))
                        Text(choice.title).font(.system(size: 11, weight: .medium)).lineLimit(1)
                    }
                    .frame(width: 80)
                    .foregroundStyle(model.highlighted == i ? .white : .primary)
                    .position(x: c.x + mid * sin(a), y: c.y - mid * cos(a))
                }
                Circle().fill(.regularMaterial).frame(width: inner * 2 - 6, height: inner * 2 - 6)
                Text(centerText).font(.system(size: 12, weight: .semibold))
                    .multilineTextAlignment(.center).frame(width: inner * 2 - 14)
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
    }

    var centerText: String {
        if n == 0 { return "Nothing to do for these files" }
        if let i = model.highlighted, model.choices.indices.contains(i) { return model.choices[i].title }
        return model.kind.title
    }
    private var n: Int { model.choices.count }
}
