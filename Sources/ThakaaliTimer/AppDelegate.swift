import AppKit
import Combine
import SwiftUI

@main
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    private var settings: AppSettings!
    private var engine: TimerEngine!
    private var overlay: OverlayController?
    private var statusBar: StatusBarController?
    private var settingsWindow: NSWindow?
    private var dockCancellable: AnyCancellable?

    static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        // Starts as a menu bar app (Info.plist sets LSUIElement); the Dock setting is applied at launch.
        app.setActivationPolicy(.accessory)
        app.run()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        AppFont.registerBundledFonts()
        settings = AppSettings()
        engine = TimerEngine(settings: settings)
        overlay = OverlayController(engine: engine, settings: settings)
        statusBar = StatusBarController(engine: engine, settings: settings) { [weak self] in
            self?.showSettings()
        }
        engine.onSessionFinished = { [weak self] kind in
            self?.sessionFinished(kind)
        }

        NSApp.mainMenu = makeMainMenu()
        dockCancellable = settings.$showInDock
            .removeDuplicates()
            .sink { show in
                NSApp.setActivationPolicy(show ? .regular : .accessory)
            }
    }

    /// Clicking the Dock icon opens Settings, since the app has no main window.
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag {
            showSettings()
        }
        return true
    }

    /// The app menu shown while it's frontmost from the Dock or ⌘-Tab, so ⌘Q and ⌘, work.
    private func makeMainMenu() -> NSMenu {
        let appMenu = NSMenu()
        let settingsItem = NSMenuItem(title: "Settings…", action: #selector(openSettingsFromMenu), keyEquivalent: ",")
        settingsItem.target = self
        appMenu.addItem(settingsItem)
        appMenu.addItem(.separator())
        appMenu.addItem(NSMenuItem(title: "Hide Thakaali Timer", action: #selector(NSApplication.hide(_:)), keyEquivalent: "h"))
        appMenu.addItem(NSMenuItem(title: "Quit Thakaali Timer", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))

        let appItem = NSMenuItem()
        appItem.submenu = appMenu
        let mainMenu = NSMenu()
        mainMenu.addItem(appItem)

        // Lets ⌘W close Settings.
        let windowMenu = NSMenu(title: "Window")
        windowMenu.addItem(NSMenuItem(title: "Close", action: #selector(NSWindow.performClose(_:)), keyEquivalent: "w"))
        let windowItem = NSMenuItem()
        windowItem.submenu = windowMenu
        mainMenu.addItem(windowItem)
        return mainMenu
    }

    @objc private func openSettingsFromMenu() {
        showSettings()
    }

    private func sessionFinished(_ kind: SessionKind) {
        if settings.playSound {
            // A built-in macOS alert sound, played by name rather than bundled.
            NSSound(named: "Glass")?.play()
        }
        let next = engine.nextKind(after: kind)
        switch settings.endStyle {
        case .autostart:
            engine.start(next)
        case .menu:
            // Leave the timer callback before opening the menu's tracking loop.
            Task { @MainActor [weak self] in
                self?.statusBar?.presentFinishMenu(after: kind)
            }
        case .corner:
            Task { @MainActor [weak self] in
                self?.statusBar?.popUpFinishMenuAtCorner(after: kind)
            }
        case .alert:
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
