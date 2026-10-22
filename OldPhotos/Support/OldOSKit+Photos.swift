import SwiftUI
import UIKit

// OldOS drawing helpers needed by the Photos screens that OldSafari never used.
// `OldOSKit.swift` is shared verbatim with OldSafari; additions live here.

extension View {
    @ViewBuilder
    func `if`<Content: View>(_ condition: Bool, content: (Self) -> Content) -> some View {
        if condition {
            content(self)
        } else {
            self
        }
    }

    /// OldOS `innerShadowFull`: the soft grey glow on all four edges of a
    /// Camera Roll thumbnail.
    func oldOSInnerShadowFull(color: Color, radius: CGFloat = 0.1) -> some View {
        modifier(OldOSInnerShadowFull(color: color, radius: min(max(0, radius), 1)))
    }

    /// OldOS `animationsDisabled()`.
    func oldOSAnimationsDisabled() -> some View {
        transaction { $0.animation = nil }
    }
}

private struct OldOSInnerShadowFull: ViewModifier {
    var color: Color
    var radius: CGFloat

    private var colors: [Color] {
        [color.opacity(0.75), color.opacity(0.0), .clear]
    }

    func body(content: Content) -> some View {
        GeometryReader { geo in
            let side = CGFloat(3) * min(geo.size.width, geo.size.height) / 2 * radius
            content
                .overlay(LinearGradient(gradient: Gradient(colors: colors), startPoint: .top, endPoint: .bottom).frame(height: side), alignment: .top)
                .overlay(LinearGradient(gradient: Gradient(colors: colors), startPoint: .bottom, endPoint: .top).frame(height: side), alignment: .bottom)
                .overlay(LinearGradient(gradient: Gradient(colors: colors), startPoint: .leading, endPoint: .trailing).frame(width: side), alignment: .leading)
                .overlay(LinearGradient(gradient: Gradient(colors: colors), startPoint: .trailing, endPoint: .leading).frame(width: side), alignment: .trailing)
                .allowsHitTesting(true)
        }
    }
}

extension Color {
    /// PureSwiftUI `cgLightGray` (white 0.667), the "12 Photos, 3 Videos" footer.
    static let oldOSLightGray = Color(white: 0.667)
}

extension Collection {
    subscript(optional index: Index) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}

enum OldPhotosHaptics {
    static func tap() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    static func press() {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }
}

extension OldOSScreen {
    static var keyWindow: UIWindow? {
        let windows = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
        return windows.first(where: { $0.isKeyWindow }) ?? windows.first
    }

    /// The topmost presented controller, used to show system sheets / alerts.
    static var topController: UIViewController? {
        var top = keyWindow?.rootViewController
        while let presented = top?.presentedViewController {
            top = presented
        }
        return top
    }
}

/// System alerts (follow Aspect UI through the window).
enum PhotosAlert {
    static func show(title: String, message: String) {
        DispatchQueue.main.async {
            let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "OK", style: .cancel))
            OldOSScreen.topController?.present(alert, animated: true)
        }
    }
}

/// "m:ss" video durations (`camera_roll`).
func oldPhotosDuration(_ seconds: Double) -> String {
    let total = Int(max(0, seconds.isFinite ? seconds : 0).rounded())
    if total >= 3600 {
        return String(format: "%d:%02d:%02d", total / 3600, (total % 3600) / 60, total % 60)
    }
    return String(format: "%01d:%02d", (total % 3600) / 60, (total % 3600) % 60)
}
