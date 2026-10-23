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
            let outer = min(geo.size.width, geo.size.height) / 2 - 14
            let inner = WheelController.deadZone
            let c = CGPoint(x: geo.size.width / 2, y: geo.size.height / 2)
            let n = model.choices.count
            ZStack {
                // Glass is costly: drawn once per open, never redrawn on hover (equatable skips it).
                GlassRing(count: n, inner: inner, outer: outer).equatable()
                if let h = model.highlighted, h < n {  // cheap orange layer is all that changes on hover
                    Segment(index: h, count: n, inner: inner, outer: outer)
                        .fill(Color.orange.opacity(0.45))
                        .transition(.opacity)
                }
                ForEach(Array(model.choices.enumerated()), id: \.offset) { i, choice in
                    let a = WheelGeometry.angle(of: i, count: n), mid = (inner + outer) / 2
                    VStack(spacing: 3) {
                        Image(systemName: choice.symbol).font(.system(size: 17, weight: .semibold))
                        Text(choice.title).font(.system(size: 11, weight: .semibold, design: .rounded))
                            .lineLimit(2).minimumScaleFactor(0.75).multilineTextAlignment(.center)
                    }
                    .frame(width: 74)
                    .foregroundStyle(.primary)
                    .shadow(color: .white.opacity(0.6), radius: 2)
                    .position(x: c.x + mid * sin(a), y: c.y - mid * cos(a))
                }
                Text(centerText)
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .multilineTextAlignment(.center).lineLimit(3)
                    .frame(width: inner * 2 - 16, height: inner * 2 - 16)
                    .position(c)
            }
            .animation(.easeOut(duration: 0.08), value: model.highlighted)
            .scaleEffect(shown ? 1 : 0.7)
            .opacity(shown ? 1 : 0)
            .animation(.spring(response: 0.28, dampingFraction: 0.75), value: shown)
        }
        .onAppear { DispatchQueue.main.async { shown = true } }  // next frame, so the change animates
    }

    var centerText: String {
        if model.choices.isEmpty { return "Nothing to do for these files" }
        if let i = model.highlighted, model.choices.indices.contains(i) { return model.choices[i].title }
        return model.kind.title
    }
}

/// All segments plus the centre disc as one Liquid Glass group, faded once as a whole.
struct GlassRing: View, Equatable {
    let count: Int
    let inner: CGFloat, outer: CGFloat

    var body: some View {
        let slices = ZStack {
            ForEach(0..<count, id: \.self) { i in
                Segment(index: i, count: count, inner: inner, outer: outer).clearGlass()
            }
            Circle().clearGlass().frame(width: inner * 2 - 16, height: inner * 2 - 16)
        }
        Group {
            if #available(macOS 26, *) { GlassEffectContainer { slices } } else { slices }
        }
        .compositingGroup()
        .opacity(0.75)
    }
}

/// One tangerine segment, drawn by the tested core outline (flipped to SwiftUI's y-down).
struct Segment: Shape {
    let index: Int, count: Int
    let inner: CGFloat, outer: CGFloat

    func path(in rect: CGRect) -> Path {
        let c = CGPoint(x: rect.midX, y: rect.midY)
        let cg = WheelGeometry.slicePath(index: index, count: count, center: c,
                                         inner: inner, outer: outer, gap: 5, corner: 12)
        let flip = CGAffineTransform(translationX: 0, y: rect.midY * 2).scaledBy(x: 1, y: -1)
        return Path(cg).applying(flip)
    }
}

extension Shape {
    /// Colourless, very clear Liquid Glass.
    @ViewBuilder func clearGlass() -> some View {
        if #available(macOS 26, *) {
            Color.clear.glassEffect(.clear, in: self)
        } else {
            fill(.ultraThinMaterial.opacity(0.6)).overlay(stroke(.white.opacity(0.35), lineWidth: 1))
        }
    }
}
