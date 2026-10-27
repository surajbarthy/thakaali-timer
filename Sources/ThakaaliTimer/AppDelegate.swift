import AppKit
import SwiftUI

@main
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    private var settings: AppSettings!
    private var engine: TimerEngine!
    private var overlay: OverlayController?
    private var statusBar: StatusBarController?
    private var settingsWindow: NSWindow?

    static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        // Menu bar only, no Dock icon (Info.plist also sets LSUIElement for the bundled app).
        app.setActivationPolicy(.accessory)
        app.run()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        settings = AppSettings()
        engine = TimerEngine(settings: settings)
        overlay = OverlayController(engine: engine, settings: settings)
        statusBar = StatusBarController(engine: engine, settings: settings) { [weak self] in
            self?.showSettings()
        }
        engine.onSessionFinished = { [weak self] kind in
            self?.sessionFinished(kind)
        }
    }

    private func sessionFinished(_ kind: SessionKind) {
        NSSound(named: "Glass")?.play()
        switch settings.endMode {
        case .autostart:
            engine.start(engine.nextKind(after: kind))
        case .ask:
            // Leave the timer callback before running a modal alert.
            Task { @MainActor [weak self] in
                self?.askWhatNext(after: kind)
            }
        }
    }

    private func askWhatNext(after kind: SessionKind) {
        let next = engine.nextKind(after: kind)
        let alert = NSAlert()
        alert.messageText = kind == .tomato ? "Tomato done" : "\(kind.title) over"
        alert.informativeText = "Hold ⌥ Option while clicking Extend to add 15 minutes instead of 5."
        alert.addButton(withTitle: "Start \(next.title)")
        alert.addButton(withTitle: "Extend 5 min")
        alert.addButton(withTitle: "Stop")

        NSApp.activate(ignoringOtherApps: true)
        switch alert.runModal() {
        case .alertFirstButtonReturn:
            engine.start(next)
        case .alertSecondButtonReturn:
            let minutes = NSEvent.modifierFlags.contains(.option) ? 15 : 5
            engine.extend(kind, minutes: minutes)
        default:
            break
        }
    }

    private func showSettings() {
        if settingsWindow == nil {
            let host = NSHostingController(rootView: SettingsView(settings: settings))
            let window = NSWindow(contentViewController: host)
            window.title = "Thakaali Timer Settings"
            window.styleMask = [.titled, .closable]
            window.isReleasedWhenClosed = false
            window.delegate = self
            window.center()
            settingsWindow = window
        }
        overlay?.previewing = true
        NSApp.activate(ignoringOtherApps: true)
        settingsWindow?.makeKeyAndOrderFront(nil)
    }

    func windowWillClose(_ notification: Notification) {
        overlay?.previewing = false
    }
}
