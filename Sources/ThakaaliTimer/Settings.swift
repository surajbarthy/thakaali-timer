import AppKit
import Combine

/// Which screen edge the progress line sits on.
enum LineEdge: String, CaseIterable, Identifiable {
    case top, bottom, left, right

    var id: String { rawValue }
    var label: String { rawValue.capitalized }
    var isHorizontal: Bool { self == .top || self == .bottom }
}

/// What happens when a tomato or break runs out.
enum EndMode: String, CaseIterable, Identifiable {
    case ask, autostart

    var id: String { rawValue }

    var title: String {
        switch self {
        case .ask: return "Ask what to do"
        case .autostart: return "Autostart next"
        }
    }

    var detail: String {
        switch self {
        case .ask: return "An alert asks whether to start the next session or extend this one."
        case .autostart: return "The next session starts automatically."
        }
    }
}

/// User preferences, persisted in UserDefaults.
@MainActor
final class AppSettings: ObservableObject {
    private enum Key {
        static let edge = "lineEdge"
        static let thickness = "lineThickness"
        static let focusMinutes = "focusMinutes"
        static let shortBreakMinutes = "shortBreakMinutes"
        static let longBreakMinutes = "longBreakMinutes"
        static let longBreakEvery = "longBreakEvery"
        static let endMode = "endMode"
        static let showTimeInMenuBar = "showTimeInMenuBar"
    }

    static let thicknessRange: ClosedRange<Double> = 1...30

    private let defaults: UserDefaults

    @Published var edge: LineEdge { didSet { defaults.set(edge.rawValue, forKey: Key.edge) } }
    @Published var thickness: Double { didSet { defaults.set(thickness, forKey: Key.thickness) } }
    @Published var focusMinutes: Int { didSet { defaults.set(focusMinutes, forKey: Key.focusMinutes) } }
    @Published var shortBreakMinutes: Int { didSet { defaults.set(shortBreakMinutes, forKey: Key.shortBreakMinutes) } }
    @Published var longBreakMinutes: Int { didSet { defaults.set(longBreakMinutes, forKey: Key.longBreakMinutes) } }
    @Published var longBreakEvery: Int { didSet { defaults.set(longBreakEvery, forKey: Key.longBreakEvery) } }
    @Published var endMode: EndMode { didSet { defaults.set(endMode.rawValue, forKey: Key.endMode) } }
    @Published var showTimeInMenuBar: Bool { didSet { defaults.set(showTimeInMenuBar, forKey: Key.showTimeInMenuBar) } }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        defaults.register(defaults: [
            Key.edge: LineEdge.top.rawValue,
            Key.thickness: 4.0,
            Key.focusMinutes: 25,
            Key.shortBreakMinutes: 5,
            Key.longBreakMinutes: 15,
            Key.longBreakEvery: 4,
            Key.endMode: EndMode.ask.rawValue,
            Key.showTimeInMenuBar: true,
        ])

        edge = LineEdge(rawValue: defaults.string(forKey: Key.edge) ?? "") ?? .top
        thickness = defaults.double(forKey: Key.thickness)
        focusMinutes = defaults.integer(forKey: Key.focusMinutes)
        shortBreakMinutes = defaults.integer(forKey: Key.shortBreakMinutes)
        longBreakMinutes = defaults.integer(forKey: Key.longBreakMinutes)
        longBreakEvery = defaults.integer(forKey: Key.longBreakEvery)
        endMode = EndMode(rawValue: defaults.string(forKey: Key.endMode) ?? "") ?? .ask
        showTimeInMenuBar = defaults.bool(forKey: Key.showTimeInMenuBar)
    }
}
