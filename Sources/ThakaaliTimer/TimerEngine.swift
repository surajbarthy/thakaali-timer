import AppKit
import Combine

enum SessionKind: Equatable {
    case tomato, shortBreak, longBreak

    var isBreak: Bool { self != .tomato }

    var title: String {
        switch self {
        case .tomato: return "Tomato"
        case .shortBreak: return "Short break"
        case .longBreak: return "Long break"
        }
    }

    /// Vermilion while focusing, green on a break. One fixed pair, since the line can sit
    /// over light or dark windows whatever the system appearance is.
    var color: NSColor {
        isBreak
            ? NSColor(srgbRed: 0x1F / 255.0, green: 0x9D / 255.0, blue: 0x63 / 255.0, alpha: 1) // #1F9D63
            : NSColor(srgbRed: 0xD9 / 255.0, green: 0x48 / 255.0, blue: 0x0F / 255.0, alpha: 1) // #D9480F
    }
}

/// The pomodoro state machine. Publishes a fresh `now` on every tick so views can redraw.
@MainActor
final class TimerEngine: NSObject, ObservableObject {
    struct Session: Equatable {
        let kind: SessionKind
        let total: TimeInterval
        /// Extensions don't count as another finished tomato.
        let countsTowardCycle: Bool
    }

    enum State: Equatable {
        case idle
        case running(Session, endsAt: Date)
        case paused(Session, remaining: TimeInterval)
    }

    static let tickInterval: TimeInterval = 0.25

    @Published private(set) var state: State = .idle
    @Published private(set) var now = Date()
    @Published private(set) var completedTomatoes = 0
    /// Bumped whenever a new session (not a resume) begins.
    private(set) var startCount = 0

    /// Called after a session runs out, with the kind that just ended.
    var onSessionFinished: ((SessionKind) -> Void)?

    private let settings: AppSettings
    private var ticker: Timer?

    init(settings: AppSettings) {
        self.settings = settings
        super.init()
    }

    var session: Session? {
        switch state {
        case .idle: return nil
        case .running(let session, _), .paused(let session, _): return session
        }
    }

    var isPaused: Bool {
        if case .paused = state { return true }
        return false
    }

    var remaining: TimeInterval { remaining(at: now) }

    func remaining(at date: Date) -> TimeInterval {
        switch state {
        case .idle: return 0
        case .running(_, let endsAt): return max(0, endsAt.timeIntervalSince(date))
        case .paused(_, let remaining): return remaining
        }
    }

    /// 1 at the start of a session, 0 when it runs out.
    var fractionRemaining: Double { fractionRemaining(at: now) }

    func fractionRemaining(at date: Date) -> Double {
        guard let session, session.total > 0 else { return 0 }
        return min(1, max(0, remaining(at: date) / session.total))
    }

    /// The break that would start now: a long one after every Nth tomato.
    var upcomingBreak: SessionKind {
        let every = max(1, settings.longBreakEvery)
        return completedTomatoes > 0 && completedTomatoes % every == 0 ? .longBreak : .shortBreak
    }

    func nextKind(after kind: SessionKind) -> SessionKind {
        kind == .tomato ? upcomingBreak : .tomato
    }

    func duration(of kind: SessionKind) -> TimeInterval {
        let minutes: Int
        switch kind {
        case .tomato: minutes = settings.focusMinutes
        case .shortBreak: minutes = settings.shortBreakMinutes
        case .longBreak: minutes = settings.longBreakMinutes
        }
        return TimeInterval(max(1, minutes) * 60)
    }

    func startTomato() { start(.tomato) }

    func startBreak() { start(upcomingBreak) }

    func start(_ kind: SessionKind) {
        begin(Session(kind: kind, total: duration(of: kind), countsTowardCycle: true))
    }

    func extend(_ kind: SessionKind, minutes: Int) {
        begin(Session(kind: kind, total: TimeInterval(minutes * 60), countsTowardCycle: false))
    }

    func pause() {
        guard case .running(let session, let endsAt) = state else { return }
        stopTicker()
        now = Date()
        state = .paused(session, remaining: max(0, endsAt.timeIntervalSince(now)))
    }

    func resume() {
        guard case .paused(let session, let remaining) = state else { return }
        now = Date()
        state = .running(session, endsAt: now.addingTimeInterval(remaining))
        startTicker()
    }

    func stop() {
        stopTicker()
        state = .idle
    }

    private func begin(_ session: Session) {
        startCount += 1
        now = Date()
        state = .running(session, endsAt: now.addingTimeInterval(session.total))
        startTicker()
    }

    private func startTicker() {
        stopTicker()
        let timer = Timer(timeInterval: Self.tickInterval, target: self, selector: #selector(tick), userInfo: nil, repeats: true)
        timer.tolerance = 0.05
        // Common modes keep the line moving while a menu is open.
        RunLoop.main.add(timer, forMode: .common)
        ticker = timer
    }

    private func stopTicker() {
        ticker?.invalidate()
        ticker = nil
    }

    @objc private func tick() {
        now = Date()
        guard case .running(let session, let endsAt) = state, endsAt <= now else { return }
        stop()
        if session.kind == .tomato && session.countsTowardCycle {
            completedTomatoes += 1
        }
        onSessionFinished?(session.kind)
    }
}
