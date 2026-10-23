import AppKit
import SwiftUI
import TangeloCore

final class WheelModel: ObservableObject {
    @Published var kind: WheelKind = .conversion
    @Published var choices: [WheelChoice] = []
    @Published var highlighted: Int?
    @Published var opened = UUID()  // new id per open replays the pop-in animation
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
        if panel?.isVisible != true { model.opened = UUID() }
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

struct WheelGraphic: View {
    @ObservedObject var model: WheelModel
    // New identity per open resets `shown` in WheelBody, so the pop-in plays every time.
    var body: some View { WheelBody(model: model).id(model.opened) }
}

struct WheelBody: View {
    @ObservedObject var model: WheelModel
    @State private var shown = false

    var body: some View {
        GeometryReader { geo in
            let outer = min(geo.size.width, geo.size.height) / 2 - 10
            let ring = outer - 52
            let n = model.choices.count
            let bubble = WheelGeometry.bubbleSize(count: n, ringRadius: ring, maxSize: 84)
            let c = CGPoint(x: geo.size.width / 2, y: geo.size.height / 2)
            ZStack {
                Circle().fill(.ultraThinMaterial)
                    .overlay(Circle().stroke(.white.opacity(0.35), lineWidth: 1))
                    .shadow(color: .black.opacity(0.18), radius: 8, y: 2)
                    .frame(width: outer * 2, height: outer * 2)
                ForEach(Array(model.choices.enumerated()), id: \.offset) { i, choice in
                    let a = WheelGeometry.angle(of: i, count: n)
                    let hot = model.highlighted == i
                    Petal(choice: choice, tint: Self.tint(i, n), hot: hot, size: bubble)
                        .position(x: c.x + ring * sin(a), y: c.y - ring * cos(a))
                        .scaleEffect(shown ? 1 : 0.3, anchor: UnitPoint(x: 0.5, y: 0.5))
                        .opacity(shown ? 1 : 0)
                        .animation(.spring(response: 0.35, dampingFraction: 0.65).delay(Double(i) * 0.025), value: shown)
                }
                Text(centerText)
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .multilineTextAlignment(.center)
                    .lineLimit(3)
                    .padding(.horizontal, 10).padding(.vertical, 6)
                    .frame(maxWidth: 96)
                    .background(Capsule().fill(.regularMaterial))
                    .animation(.easeOut(duration: 0.12), value: centerText)
            }
            .frame(width: geo.size.width, height: geo.size.height)
            .scaleEffect(shown ? 1 : 0.85)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: shown)
        }
        .onAppear { DispatchQueue.main.async { shown = true } }  // next frame, so the change animates
    }

    /// Soft, evenly spread hue per choice.
    static func tint(_ i: Int, _ n: Int) -> Color {
        Color(hue: 0.55 + Double(i) / Double(max(n, 1)) * 0.45, saturation: 0.35, brightness: 0.95)
    }

    var centerText: String {
        if model.choices.isEmpty { return "Nothing to do for these files" }
        if let i = model.highlighted, model.choices.indices.contains(i) { return model.choices[i].title }
        return model.kind.title
    }
}

/// One round choice: soft glass bubble, turns orange and grows when the pointer is over it.
struct Petal: View {
    let choice: WheelChoice
    let tint: Color
    let hot: Bool
    let size: CGFloat

    var body: some View {
        ZStack {
            Circle().fill(.thinMaterial)
            Circle().fill(LinearGradient(colors: hot ? [.orange, Color(red: 1, green: 0.45, blue: 0.1)]
                                                     : [tint.opacity(0.55), tint.opacity(0.25)],
                                         startPoint: .top, endPoint: .bottom))
            Circle().stroke(.white.opacity(hot ? 0.8 : 0.4), lineWidth: 1)
            VStack(spacing: 2) {
                Image(systemName: choice.symbol).font(.system(size: size * 0.26, weight: .semibold))
                Text(choice.title).font(.system(size: 10, weight: .semibold, design: .rounded))
                    .lineLimit(2).minimumScaleFactor(0.7).multilineTextAlignment(.center)
            }
            .padding(6)
            .foregroundStyle(hot ? .white : .primary)
        }
        .frame(width: size, height: size)
        .shadow(color: hot ? .orange.opacity(0.6) : .black.opacity(0.12), radius: hot ? 10 : 3, y: hot ? 0 : 1)
        .scaleEffect(hot ? 1.18 : 1)
        .animation(.spring(response: 0.25, dampingFraction: 0.55), value: hot)
    }
}
