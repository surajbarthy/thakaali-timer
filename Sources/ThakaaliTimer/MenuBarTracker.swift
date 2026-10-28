import AppKit

/// Finds where each display's menu bar currently is, so the top line can sit right under it,
/// rise to the very top while a full-screen app hides it, and follow it as it slides back down.
///
/// Reads the menu bar windows' positions from the window list. Window bounds are readable
/// without Screen Recording permission; only titles and contents need it.
@MainActor
enum MenuBarTracker {
    /// Menu bar windows on screen right now, in Cocoa screen coordinates.
    static func menuBarRects() -> [NSRect] {
        guard let primary = NSScreen.screens.first,
              let info = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]]
        else { return [] }
        let menuLevel = Int(CGWindowLevelForKey(.mainMenuWindow))
        return info.compactMap { window in
            guard (window[kCGWindowLayer as String] as? Int) == menuLevel,
                  let dict = window[kCGWindowBounds as String] as? NSDictionary,
                  let bounds = CGRect(dictionaryRepresentation: dict as CFDictionary),
                  bounds.width > 0, bounds.height > 0
            else { return nil }
            // Window-list bounds run top-down from the primary display's top edge.
            return NSRect(x: bounds.minX, y: primary.frame.maxY - bounds.maxY, width: bounds.width, height: bounds.height)
        }
    }

    /// Where the top line should hang from on this screen: just under the menu bar while it shows,
    /// the top of the screen while it's hidden, but never up beside a notch. Falls back to the
    /// visible frame if no menu bar shows anywhere, in case the window list stops reporting it.
    static func topEdge(of screen: NSScreen, menuBars: [NSRect]) -> CGFloat {
        let f = screen.frame
        guard !menuBars.isEmpty else { return screen.visibleFrame.maxY }
        let belowNotch = f.maxY - notchHeight(of: screen)
        let bottoms = menuBars.filter { $0.intersects(f) }.map(\.minY)
        guard let bottom = bottoms.min() else { return belowNotch }
        return min(belowNotch, max(f.minY, bottom))
    }

    /// Height of the band the camera notch sits in, or 0 on a screen without one.
    private static func notchHeight(of screen: NSScreen) -> CGFloat {
        if #available(macOS 12.0, *) {
            return screen.safeAreaInsets.top
        }
        return 0
    }
}
