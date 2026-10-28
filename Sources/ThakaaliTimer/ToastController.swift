import AppKit
import SwiftUI

/// A small, non-activating toast shown at the corner where the line ended.
@MainActor
final class ToastController {
    private var panel: NSPanel?

    struct Actions {
        let startNext: () -> Void
        let extend: (_ minutes: Int) -> Void
        let stop: () -> Void
    }

    func show(finished kind: SessionKind, next: SessionKind, settings: AppSettings, actions: Actions) {
        dismiss()

        let view = ToastView(
            title: kind == .tomato ? "Tomato done" : "\(kind.title) over",
            primaryTitle: "Start \(next.title.lowercased())",
            primaryColor: Color(nsColor: next.color),
            onPrimary: { [weak self] in
                self?.dismiss()
                actions.startNext()
            },
            onExtend: { [weak self] in
                self?.dismiss()
                actions.extend(NSEvent.modifierFlags.contains(.option) ? 15 : 5)
            },
            onStop: { [weak self] in
                self?.dismiss()
                actions.stop()
            }
        )
        let host = NSHostingView(rootView: view)
        let size = host.fittingSize

        let panel = NSPanel(
            contentRect: NSRect(origin: .zero, size: size),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.isReleasedWhenClosed = false
        panel.becomesKeyOnlyIfNeeded = true
        panel.level = .screenSaver
        panel.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary, .ignoresCycle]
        panel.contentView = host
        panel.setFrameOrigin(Self.origin(for: size, settings: settings))
        panel.orderFrontRegardless()
        self.panel = panel
    }

    func dismiss() {
        panel?.orderOut(nil)
        panel = nil
    }

    /// The corner the tomato line drains toward, just inside the line.
    private static func origin(for size: NSSize, settings: AppSettings) -> NSPoint {
        guard let screen = NSScreen.screens.first else { return .zero }
        let f = screen.frame
        let inset = CGFloat(settings.thickness) * 2 * settings.lineStyle.spread
        let margin: CGFloat = 10
        let reversed = settings.reverseDirection
        let leftX = f.minX + margin
        let rightX = f.maxX - size.width - margin
        let topY = screen.visibleFrame.maxY - size.height - margin
        switch settings.edge {
        case .top:
            let menuBar = max(0, f.maxY - screen.visibleFrame.maxY)
            return NSPoint(x: reversed ? leftX : rightX, y: f.maxY - menuBar - inset - size.height - margin)
        case .bottom:
            return NSPoint(x: reversed ? leftX : rightX, y: f.minY + inset + margin)
        case .left:
            return NSPoint(x: f.minX + inset + margin, y: reversed ? topY : f.minY + margin)
        case .right:
            return NSPoint(x: f.maxX - inset - size.width - margin, y: reversed ? topY : f.minY + margin)
        }
    }
}

private struct ToastView: View {
    let title: String
    let primaryTitle: String
    let primaryColor: Color
    let onPrimary: () -> Void
    let onExtend: () -> Void
    let onStop: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.geist(13, weight: .semibold))
            HStack(spacing: 6) {
                ToastButton(title: primaryTitle, fill: primaryColor, action: onPrimary)
                ToastButton(title: "+5 min", fill: Color.white.opacity(0.14), action: onExtend)
                    .help("Hold ⌥ Option for +15 min")
                ToastButton(title: "Stop", fill: Color.white.opacity(0.14), action: onStop)
            }
        }
        .foregroundColor(.white)
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color(white: 0.12, opacity: 0.92))
        )
        .fixedSize()
    }
}

private struct ToastButton: View {
    let title: String
    let fill: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.geist(12, weight: .medium))
                .padding(.horizontal, 9)
                .padding(.vertical, 4)
                .background(RoundedRectangle(cornerRadius: 6, style: .continuous).fill(fill))
        }
        .buttonStyle(.plain)
    }
}
