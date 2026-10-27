import AppKit
import Combine

/// Draws the progress line along one edge of every display.
@MainActor
final class OverlayController: NSObject {
    private let engine: TimerEngine
    private let settings: AppSettings
    private var windows: [LineWindow] = []
    private var cancellable: AnyCancellable?
    private var lastGeometry: (LineEdge, Double)?

    /// Shows a full line while idle, so thickness and position changes can be seen in Settings.
    var previewing = false {
        didSet { refresh() }
    }

    init(engine: TimerEngine, settings: AppSettings) {
        self.engine = engine
        self.settings = settings
        super.init()

        cancellable = engine.objectWillChange
            .merge(with: settings.objectWillChange)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.refresh() }

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(screensChanged),
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil
        )

        rebuildWindows()
    }

    @objc private func screensChanged() {
        rebuildWindows()
    }

    private func rebuildWindows() {
        windows.forEach { $0.close() }
        windows = NSScreen.screens.map { LineWindow(screen: $0) }
        lastGeometry = nil
        refresh()
    }

    func refresh() {
        let session = engine.session
        let visible = session != nil || previewing
        guard visible else {
            windows.forEach { $0.orderOut(nil) }
            lastGeometry = nil
            return
        }

        let edge = settings.edge
        let thickness = settings.thickness
        let geometryChanged = lastGeometry.map { $0.0 != edge || $0.1 != thickness } ?? true
        lastGeometry = (edge, thickness)

        let kind = session?.kind ?? .tomato
        let fraction = session == nil ? 1 : engine.fractionRemaining
        let color = kind.color.withAlphaComponent(engine.isPaused ? 0.45 : 1)

        for window in windows {
            guard let screen = window.targetScreen else { continue }
            let frame = Self.stripFrame(on: screen, edge: edge, thickness: thickness)
            if window.frame != frame {
                window.setFrame(frame, display: false)
            }
            window.lineView.update(
                fraction: CGFloat(fraction),
                color: color,
                edge: edge,
                animated: !geometryChanged && engine.state != .idle
            )
            if !window.isVisible {
                window.orderFrontRegardless()
            }
        }
    }

    static func stripFrame(on screen: NSScreen, edge: LineEdge, thickness: Double) -> NSRect {
        let f = screen.frame
        let t = CGFloat(thickness)
        switch edge {
        case .top: return NSRect(x: f.minX, y: f.maxY - t, width: f.width, height: t)
        case .bottom: return NSRect(x: f.minX, y: f.minY, width: f.width, height: t)
        case .left: return NSRect(x: f.minX, y: f.minY, width: t, height: f.height)
        case .right: return NSRect(x: f.maxX - t, y: f.minY, width: t, height: f.height)
        }
    }
}

/// A borderless, click-through strip that floats above everything, including full-screen apps.
final class LineWindow: NSWindow {
    let lineView = LineView(frame: .zero)
    private(set) weak var targetScreen: NSScreen?

    convenience init(screen: NSScreen) {
        self.init(contentRect: .zero, styleMask: .borderless, backing: .buffered, defer: false)
        targetScreen = screen
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        ignoresMouseEvents = true
        isReleasedWhenClosed = false
        level = .screenSaver
        collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary, .ignoresCycle]
        lineView.autoresizingMask = [.width, .height]
        contentView = lineView
    }

    // Allow the strip to sit over the menu bar.
    override func constrainFrameRect(_ frameRect: NSRect, to screen: NSScreen?) -> NSRect {
        frameRect
    }

    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

/// Fills its bounds proportionally to the time left: horizontal lines shrink toward the left, vertical ones toward the top.
final class LineView: NSView {
    private let bar = CALayer()

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.addSublayer(bar)
    }

    required init?(coder: NSCoder) {
        nil
    }

    func update(fraction: CGFloat, color: NSColor, edge: LineEdge, animated: Bool) {
        CATransaction.begin()
        if animated {
            CATransaction.setAnimationDuration(TimerEngine.tickInterval)
            CATransaction.setAnimationTimingFunction(CAMediaTimingFunction(name: .linear))
        } else {
            CATransaction.setDisableActions(true)
        }

        let b = bounds
        if edge.isHorizontal {
            bar.frame = CGRect(x: 0, y: 0, width: b.width * fraction, height: b.height)
        } else {
            let height = b.height * fraction
            bar.frame = CGRect(x: 0, y: b.height - height, width: b.width, height: height)
        }
        bar.backgroundColor = color.cgColor

        CATransaction.commit()
    }
}
