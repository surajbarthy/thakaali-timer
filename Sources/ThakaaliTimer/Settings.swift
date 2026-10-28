import AppKit
import Combine

/// Which screen edge the progress line sits on.
enum LineEdge: String, CaseIterable, Identifiable {
    case top, bottom, left, right

    var id: String { rawValue }
    var label: String { rawValue.capitalized }
    var isHorizontal: Bool { self == .top || self == .bottom }
}

/// How the line is drawn.
enum LineStyle: String, CaseIterable, Identifiable {
    case solid, feathered

    var id: String { rawValue }
    var label: String { rawValue.capitalized }

    /// How far the drawn band extends inward, as a multiple of the line thickness.
    var spread: CGFloat {
        self == .feathered ? 3 : 1
    }

    /// Fade at the moving end: the shorter of a share of the screen and a share of the line.
    var endFade: (screenShare: CGFloat, lineShare: CGFloat)? {
        self == .feathered ? (0.14, 0.4) : nil
    }
}

/// What happens when a tomato or break runs out.
enum EndStyle: String, CaseIterable, Identifiable {
    case menu, corner, alert, autostart

    var id: String { rawValue }

    var title: String {
        switch self {
        case .menu: return "Menu from the menu bar icon"
        case .corner: return "Menu where the line ended"
        case .alert: return "Alert"
        case .autostart: return "Autostart next"
        }
    }

    var detail: String {
        switch self {
        case .menu: return "The app's menu drops open with start, extend and stop."
        case .corner: return "The same small menu pops up at the corner where the line ran out."
        case .alert: return "A centred alert interrupts you and asks what to do."
        case .autostart: return "The next session starts automatically."
        }
    }
}

/// User preferences, persisted in UserDefaults.
@MainActor
final class AppSettings: ObservableObject {
    private enum Key {
        static let edge = "lineEdge"
        static let thickness = "restingThickness"
        static let lineStyle = "lineStyle"
        static let reverseDirection = "reverseDirection"
        static let focusMinutes = "focusMinutes"
        static let shortBreakMinutes = "shortBreakMinutes"
        static let longBreakMinutes = "longBreakMinutes"
        static let longBreakEvery = "longBreakEvery"
        static let endStyle = "endStyle"
        static let showTimeInMenuBar = "showCountdownInMenuBar"
    }

    /// Resting thickness; the line grows to twice this when a session starts or you point at it.
    static let thicknessRange: ClosedRange<Double> = 1...12

    private let defaults: UserDefaults

    @Published var edge: LineEdge { didSet { defaults.set(edge.rawValue, forKey: Key.edge) } }
    @Published var thickness: Double { didSet { defaults.set(thickness, forKey: Key.thickness) } }
    @Published var lineStyle: LineStyle { didSet { defaults.set(lineStyle.rawValue, forKey: Key.lineStyle) } }
    /// Anchor the line at the left (or top) instead of the right (or bottom).
    @Published var reverseDirection: Bool { didSet { defaults.set(reverseDirection, forKey: Key.reverseDirection) } }
    @Published var focusMinutes: Int { didSet { defaults.set(focusMinutes, forKey: Key.focusMinutes) } }
    @Published var shortBreakMinutes: Int { didSet { defaults.set(shortBreakMinutes, forKey: Key.shortBreakMinutes) } }
    @Published var longBreakMinutes: Int { didSet { defaults.set(longBreakMinutes, forKey: Key.longBreakMinutes) } }
    @Published var longBreakEvery: Int { didSet { defaults.set(longBreakEvery, forKey: Key.longBreakEvery) } }
    @Published var endStyle: EndStyle { didSet { defaults.set(endStyle.rawValue, forKey: Key.endStyle) } }
    @Published var showTimeInMenuBar: Bool { didSet { defaults.set(showTimeInMenuBar, forKey: Key.showTimeInMenuBar) } }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        defaults.register(defaults: [
            Key.edge: LineEdge.top.rawValue,
            Key.thickness: 3.0,
            Key.lineStyle: LineStyle.solid.rawValue,
            Key.reverseDirection: false,
            Key.focusMinutes: 25,
            Key.shortBreakMinutes: 5,
            Key.longBreakMinutes: 15,
            Key.longBreakEvery: 4,
            Key.endStyle: EndStyle.corner.rawValue,
            Key.showTimeInMenuBar: false,
        ])

        edge = LineEdge(rawValue: defaults.string(forKey: Key.edge) ?? "") ?? .top
        thickness = defaults.double(forKey: Key.thickness)
        lineStyle = LineStyle(rawValue: defaults.string(forKey: Key.lineStyle) ?? "") ?? .solid
        reverseDirection = defaults.bool(forKey: Key.reverseDirection)
        focusMinutes = defaults.integer(forKey: Key.focusMinutes)
        shortBreakMinutes = defaults.integer(forKey: Key.shortBreakMinutes)
        longBreakMinutes = defaults.integer(forKey: Key.longBreakMinutes)
        longBreakEvery = defaults.integer(forKey: Key.longBreakEvery)
        endStyle = EndStyle(rawValue: defaults.string(forKey: Key.endStyle) ?? "") ?? .corner
        showTimeInMenuBar = defaults.bool(forKey: Key.showTimeInMenuBar)
    }
}
