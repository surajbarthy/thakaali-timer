import AppKit
import Combine

/// The menu bar item: an icon, the time left, and the start/stop/pause menu.
@MainActor
final class StatusBarController: NSObject, NSMenuDelegate {
    private let item: NSStatusItem
    private let engine: TimerEngine
    private let settings: AppSettings
    private let openSettings: () -> Void
    private var cancellable: AnyCancellable?

    init(engine: TimerEngine, settings: AppSettings, openSettings: @escaping () -> Void) {
        self.engine = engine
        self.settings = settings
        self.openSettings = openSettings
        item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        super.init()

        let menu = NSMenu()
        menu.delegate = self
        item.menu = menu
        item.button?.imagePosition = .imageLeading

        cancellable = engine.objectWillChange
            .merge(with: settings.objectWillChange)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.refreshButton() }

        refreshButton()
    }

    private func refreshButton() {
        guard let button = item.button else { return }

        let symbol: String
        switch engine.state {
        case .idle: symbol = "timer"
        case .running: symbol = "circle.fill"
        case .paused: symbol = "pause.circle.fill"
        }
        let config = NSImage.SymbolConfiguration(pointSize: engine.session == nil ? 14 : 10, weight: .regular)
        let image = NSImage(systemSymbolName: symbol, accessibilityDescription: "Thakaali Timer")?
            .withSymbolConfiguration(config)
        image?.isTemplate = true
        button.image = image
        button.contentTintColor = engine.session?.kind.color

        if settings.showTimeInMenuBar, engine.session != nil {
            button.attributedTitle = NSAttributedString(
                string: " " + Self.format(engine.remaining),
                attributes: [.font: NSFont.monospacedDigitSystemFont(ofSize: NSFont.systemFontSize, weight: .regular)]
            )
        } else {
            button.attributedTitle = NSAttributedString(string: "")
        }
    }

    // MARK: Menu

    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()

        let header = NSMenuItem(title: statusText(), action: nil, keyEquivalent: "")
        header.isEnabled = false
        menu.addItem(header)
        menu.addItem(.separator())

        let kind = engine.session?.kind
        if kind != .tomato {
            menu.addItem(makeItem("Start Tomato", #selector(startTomato)))
        }
        if kind == nil || kind == .tomato {
            menu.addItem(makeItem("Start \(engine.upcomingBreak.title)", #selector(startBreak)))
        }

        switch engine.state {
        case .idle:
            break
        case .running:
            menu.addItem(makeItem("Stop", #selector(stop)))
            // Hold Option to swap Stop for Pause, like Tomato 2.
            let pause = makeItem("Pause", #selector(pause))
            pause.isAlternate = true
            pause.keyEquivalentModifierMask = .option
            menu.addItem(pause)
        case .paused:
            menu.addItem(makeItem("Resume", #selector(resume)))
            menu.addItem(makeItem("Stop", #selector(stop)))
        }

        menu.addItem(.separator())

        let positionItem = NSMenuItem(title: "Line Position", action: nil, keyEquivalent: "")
        let positionMenu = NSMenu()
        for edge in LineEdge.allCases {
            let edgeItem = makeItem(edge.label, #selector(setEdge(_:)))
            edgeItem.representedObject = edge.rawValue
            edgeItem.state = settings.edge == edge ? .on : .off
            positionMenu.addItem(edgeItem)
        }
        positionItem.submenu = positionMenu
        menu.addItem(positionItem)

        menu.addItem(makeItem("Settings…", #selector(showSettings), key: ","))
        menu.addItem(.separator())
        menu.addItem(makeItem("Quit Thakaali Timer", #selector(quit), key: "q"))
    }

    private func statusText() -> String {
        let done = engine.completedTomatoes
        let tally = done == 1 ? "1 tomato done" : "\(done) tomatoes done"
        guard let session = engine.session else { return "Idle · \(tally)" }
        let paused = engine.isPaused ? " (paused)" : ""
        return "\(session.kind.title) · \(Self.format(engine.remaining)) left\(paused) · \(tally)"
    }

    private func makeItem(_ title: String, _ action: Selector, key: String = "") -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: key)
        item.target = self
        return item
    }

    @objc private func startTomato() { engine.startTomato() }
    @objc private func startBreak() { engine.startBreak() }
    @objc private func stop() { engine.stop() }
    @objc private func pause() { engine.pause() }
    @objc private func resume() { engine.resume() }
    @objc private func showSettings() { openSettings() }
    @objc private func quit() { NSApp.terminate(nil) }

    @objc private func setEdge(_ sender: NSMenuItem) {
        guard let raw = sender.representedObject as? String, let edge = LineEdge(rawValue: raw) else { return }
        settings.edge = edge
    }

    static func format(_ seconds: TimeInterval) -> String {
        let total = Int(seconds.rounded(.up))
        return String(format: "%02d:%02d", total / 60, total % 60)
    }
}
