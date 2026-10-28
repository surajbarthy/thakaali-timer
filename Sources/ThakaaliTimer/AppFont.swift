import AppKit
import CoreText

/// Geist Mono, used for the app's own surfaces (hover tag, countdown); bundled in Contents/Resources/Fonts. Falls back to the system font when it isn't
/// available (for example under `swift run`).
enum AppFont {
    static func registerBundledFonts() {
        guard let dir = Bundle.main.resourceURL?.appendingPathComponent("Fonts"),
              let urls = try? FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil)
        else { return }
        for url in urls where url.pathExtension == "ttf" {
            CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
        }
    }

    static func mono(_ size: CGFloat) -> NSFont {
        NSFont(name: "GeistMono-Medium", size: size) ?? .monospacedDigitSystemFont(ofSize: size, weight: .medium)
    }
}
