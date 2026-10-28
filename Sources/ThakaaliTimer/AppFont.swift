import AppKit
import CoreText
import SwiftUI

/// Geist, bundled in Contents/Resources/Fonts. Falls back to the system font when it isn't
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

    static func sans(_ size: CGFloat, weight: NSFont.Weight = .regular) -> NSFont {
        let name: String
        switch weight {
        case .semibold, .bold: name = "Geist-SemiBold"
        case .medium: name = "Geist-Medium"
        default: name = "Geist-Regular"
        }
        return NSFont(name: name, size: size) ?? .systemFont(ofSize: size, weight: weight)
    }

    static func mono(_ size: CGFloat) -> NSFont {
        NSFont(name: "GeistMono-Medium", size: size) ?? .monospacedDigitSystemFont(ofSize: size, weight: .medium)
    }
}

extension Font {
    static func geist(_ size: CGFloat, weight: NSFont.Weight = .regular) -> Font {
        Font(AppFont.sans(size, weight: weight) as CTFont)
    }
}
