import AppKit
import Combine

/// Draws the progress line along one edge of every display.
///
/// The tomato line is anchored at the top-right (bottom on the side edges) and drains toward
/// that corner; the break line grows back out of the same corner until it is full.
/// "Reverse direction" anchors at the left (top on the side edges) instead.
@MainActor
final class OverlayController: NSObject {
    /// How close the pointer must be to the line, and for how long, before it counts as hovering.
    static let hoverMargin: CGFloat = 6
    static let hoverDelay: TimeInterval = 0.25
    /// How long the line stays thick after a session starts: a quick swell, then back down.
    static let startBoost: TimeInterval = 0.6
    static let frameInterval: TimeInterval = 1.0 / 30
    /// The line pulses during the last stretch of a session.
    static let pulseWindow: TimeInterval = 60
    static let pulsePeriod: TimeInterval = 3

    private let engine: TimerEngine
    private let settings: AppSettings
    private var windows: [LineWindow] = []
    private let hoverLabel = HoverLabelWindow()
    private var cancellable: AnyCancellable?
    private var frameTimer: Timer?
    private var lastFrame = Date()
    private var displayedThickness: CGFloat?
    private var lastStartCount = 0
    private var boostUntil = Date.distantPast
    private var nearSince: Date?

    /// Shows a full line while idle, so style, thickness and position changes can be seen in Settings.
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
        refresh()
    }

    func refresh() {
        if engine.startCount != lastStartCount {
            lastStartCount = engine.startCount
            boostUntil = Date().addingTimeInterval(Self.startBoost)
        }

        if engine.session != nil || previewing {
            startFrameTimer()
            renderFrame()
        } else {
            stopFrameTimer()
            windows.forEach { $0.orderOut(nil) }
            hoverLabel.orderOut(nil)
            nearSince = nil
            displayedThickness = nil
        }
    }

    private func startFrameTimer() {
        guard frameTimer == nil else { return }
        lastFrame = Date()
        let timer = Timer(timeInterval: Self.frameInterval, target: self, selector: #selector(frameTick), userInfo: nil, repeats: true)
        // Common modes keep the line moving while a menu is open.
        RunLoop.main.add(timer, forMode: .common)
        frameTimer = timer
    }

    private func stopFrameTimer() {
        frameTimer?.invalidate()
        frameTimer = nil
    }

    @objc private func frameTick() {
        renderFrame()
    }

    private func renderFrame() {
        let now = Date()
        let dt = now.timeIntervalSince(lastFrame)
        lastFrame = now

        let edge = settings.edge
        let style = settings.lineStyle
        let atStart = settings.anchorsAtStart
        let resting = CGFloat(settings.thickness)
        let peak = resting * 2

        let session = engine.session
        let pulse = pulseAmount(now: now)
        let kind = session?.kind ?? .tomato
        let remaining = session == nil ? 1 : engine.fractionRemaining(at: now)
        let length = CGFloat(kind.isBreak ? 1 - remaining : remaining)
        let color = kind.color.withAlphaComponent(engine.isPaused ? 0.45 : 1 - 0.1 * pulse)

        let current = displayedThickness ?? (now < boostUntil ? peak : resting)
        let hit = hoverHit(edge: edge, length: length, thickness: current, atStart: atStart)
        let hovering = updateHover(isNear: hit != nil, now: now)

        // Ease toward the target thickness.
        let target = hovering || now < boostUntil ? peak : resting
        var thickness = current + (target - current) * CGFloat(min(1, dt * 6))
        if abs(target - thickness) < 0.05 { thickness = target }
        displayedThickness = thickness

        for window in windows {
            guard let screen = window.targetScreen else { continue }
            let frame = Self.stripFrame(on: screen, edge: edge, extent: peak * style.spread)
            if window.frame != frame {
                window.setFrame(frame, display: false)
            }
            window.lineView.render(length: length, thickness: thickness * style.spread + resting * style.pulseSwell * pulse, color: color, edge: edge, style: style, atStart: atStart)
            if !window.isVisible {
                window.orderFrontRegardless()
            }
        }

        if hovering, session != nil, let hit {
            hoverLabel.show(text: hoverText(now: now), pointer: NSEvent.mouseLocation, lineRect: hit, edge: edge)
        } else {
            hoverLabel.orderOut(nil)
        }
    }

    /// The line's on-screen rect under the pointer (with a small margin), if any.
    private func hoverHit(edge: LineEdge, length: CGFloat, thickness: CGFloat, atStart: Bool) -> NSRect? {
        let mouse = NSEvent.mouseLocation
        for window in windows where window.isVisible {
            let band = LineView.bandRect(in: NSRect(origin: .zero, size: window.frame.size), edge: edge, length: length, thickness: thickness, atStart: atStart)
            let onScreen = band.offsetBy(dx: window.frame.minX, dy: window.frame.minY)
            if onScreen.insetBy(dx: -Self.hoverMargin, dy: -Self.hoverMargin).contains(mouse) {
                return onScreen
            }
        }
        return nil
    }

    private func updateHover(isNear: Bool, now: Date) -> Bool {
        guard isNear else {
            nearSince = nil
            return false
        }
        let since = nearSince ?? now
        nearSince = since
        return now.timeIntervalSince(since) >= Self.hoverDelay
    }

    private func hoverText(now: Date) -> String {
        let seconds = engine.remaining(at: now)
        let text = seconds < 60
            ? Self.countdown(Int(seconds.rounded(.up)), unit: "sec")
            : Self.countdown(Int((seconds / 60).rounded(.up)), unit: "min")
        return engine.isPaused ? text + " · paused" : text
    }

    private static func countdown(_ value: Int, unit: String) -> String {
        "\(value) \(unit)\(value == 1 ? "" : "s") left"
    }

    /// 0…1 breathing in the last minute of a running session. The line swells by up to a sixth
    /// of its resting thickness (about 3 → 3.5 pt) and dims to 90%, in step.
    private func pulseAmount(now: Date) -> CGFloat {
        guard settings.pulseNearEnd, case .running = engine.state else { return 0 }
        let seconds = engine.remaining(at: now)
        guard seconds > 0, seconds <= Self.pulseWindow else { return 0 }
        let phase = now.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: Self.pulsePeriod) / Self.pulsePeriod
        return CGFloat(0.5 - 0.5 * cos(phase * 2 * .pi))
    }

    /// The strip each window covers. The top line sits just under the menu bar, clear of the notch.
    static func stripFrame(on screen: NSScreen, edge: LineEdge, extent: CGFloat) -> NSRect {
        let f = screen.frame
        switch edge {
        case .top:
            let menuBar = max(0, f.maxY - screen.visibleFrame.maxY)
            return NSRect(x: f.minX, y: f.maxY - menuBar - extent, width: f.width, height: extent)
        case .bottom: return NSRect(x: f.minX, y: f.minY, width: f.width, height: extent)
        case .left: return NSRect(x: f.minX, y: f.minY, width: extent, height: f.height)
        case .right: return NSRect(x: f.maxX - extent, y: f.minY, width: extent, height: f.height)
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

    // Allow the strip to sit over the menu bar area.
    override func constrainFrameRect(_ frameRect: NSRect, to screen: NSScreen?) -> NSRect {
        frameRect
    }

    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

/// Draws one band hugging the screen edge. Its length is anchored at the left (horizontal) or top
/// (vertical) end when atStart is true, otherwise at the right or bottom; the other end moves.
final class LineView: NSView {
    private let fill = CAGradientLayer()
    private let endFade = CAGradientLayer()

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.addSublayer(fill)
        fill.mask = endFade
    }

    required init?(coder: NSCoder) {
        nil
    }

    static func bandRect(in bounds: NSRect, edge: LineEdge, length: CGFloat, thickness: CGFloat, atStart: Bool) -> NSRect {
        let w = bounds.width
        let h = bounds.height
        let t = min(thickness, edge.isHorizontal ? h : w)
        let x = atStart ? 0 : w * (1 - length)
        let y = atStart ? h * (1 - length) : 0
        switch edge {
        case .top: return NSRect(x: x, y: h - t, width: w * length, height: t)
        case .bottom: return NSRect(x: x, y: 0, width: w * length, height: t)
        case .left: return NSRect(x: 0, y: y, width: t, height: h * length)
        case .right: return NSRect(x: w - t, y: y, width: t, height: h * length)
        }
    }

    func render(length: CGFloat, thickness: CGFloat, color: NSColor, edge: LineEdge, style: LineStyle, atStart: Bool) {
        CATransaction.begin()
        CATransaction.setDisableActions(true)

        fill.frame = Self.bandRect(in: bounds, edge: edge, length: length, thickness: thickness, atStart: atStart)
        endFade.frame = fill.bounds

        // Across the band: full colour at the screen edge, fading inward unless solid.
        fill.colors = style == .solid
            ? [color.cgColor, color.cgColor]
            : [color.cgColor, color.withAlphaComponent(0).cgColor]
        switch edge {
        case .top: (fill.startPoint, fill.endPoint) = (CGPoint(x: 0.5, y: 1), CGPoint(x: 0.5, y: 0))
        case .bottom: (fill.startPoint, fill.endPoint) = (CGPoint(x: 0.5, y: 0), CGPoint(x: 0.5, y: 1))
        case .left: (fill.startPoint, fill.endPoint) = (CGPoint(x: 0, y: 0.5), CGPoint(x: 1, y: 0.5))
        case .right: (fill.startPoint, fill.endPoint) = (CGPoint(x: 1, y: 0.5), CGPoint(x: 0, y: 0.5))
        }

        // Along the band: soften the moving end when feathered.
        let fullLength = edge.isHorizontal ? bounds.width : bounds.height
        let lineLength = max(1, fullLength * length)
        var fadeShare: CGFloat = 0
        if let fade = style.endFade {
            fadeShare = min(1, min(fullLength * fade.screenShare, lineLength * fade.lineShare) / lineLength)
        }
        let opaque = NSColor.black.cgColor
        if fadeShare > 0 {
            endFade.colors = [NSColor.clear.cgColor, opaque, opaque]
            endFade.locations = [0, NSNumber(value: Double(fadeShare)), 1]
        } else {
            endFade.colors = [opaque, opaque]
            endFade.locations = [0, 1]
        }
        // The gradient starts (clear) at the moving end.
        switch (edge.isHorizontal, atStart) {
        case (true, false): (endFade.startPoint, endFade.endPoint) = (CGPoint(x: 0, y: 0.5), CGPoint(x: 1, y: 0.5))
        case (true, true): (endFade.startPoint, endFade.endPoint) = (CGPoint(x: 1, y: 0.5), CGPoint(x: 0, y: 0.5))
        case (false, false): (endFade.startPoint, endFade.endPoint) = (CGPoint(x: 0.5, y: 1), CGPoint(x: 0.5, y: 0))
        case (false, true): (endFade.startPoint, endFade.endPoint) = (CGPoint(x: 0.5, y: 0), CGPoint(x: 0.5, y: 1))
        }

        CATransaction.commit()
    }
}

/// A tiny "12 min left" tag that follows the pointer while it rests on the line.
final class HoverLabelWindow: NSPanel {
    private let field = NSTextField(labelWithString: "")

    convenience init() {
        self.init(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        ignoresMouseEvents = true
        isReleasedWhenClosed = false
        level = .screenSaver
        collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary, .ignoresCycle]

        let container = NSView()
        container.wantsLayer = true
        container.layer?.backgroundColor = NSColor(white: 0.08, alpha: 0.85).cgColor
        container.layer?.cornerRadius = 5
        field.font = AppFont.mono(11)
        field.textColor = .white
        container.addSubview(field)
        contentView = container
    }

    func show(text: String, pointer: NSPoint, lineRect: NSRect, edge: LineEdge) {
        if field.stringValue != text {
            field.stringValue = text
            field.sizeToFit()
        }
        field.setFrameOrigin(NSPoint(x: 7, y: 3))
        let size = NSSize(width: field.frame.width + 14, height: field.frame.height + 6)
        let gap: CGFloat = 6

        let origin: NSPoint
        switch edge {
        case .top: origin = NSPoint(x: pointer.x - size.width / 2, y: lineRect.minY - size.height - gap)
        case .bottom: origin = NSPoint(x: pointer.x - size.width / 2, y: lineRect.maxY + gap)
        case .left: origin = NSPoint(x: lineRect.maxX + gap, y: pointer.y - size.height / 2)
        case .right: origin = NSPoint(x: lineRect.minX - size.width - gap, y: pointer.y - size.height / 2)
        }
        setFrame(NSRect(origin: origin, size: size), display: true)
        if !isVisible {
            orderFrontRegardless()
        }
    }
}
