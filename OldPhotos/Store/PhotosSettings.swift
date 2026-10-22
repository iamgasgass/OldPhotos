import SwiftUI
import UIKit

/// "Aspect UI" (Settings › OldPhotos, from `Settings.bundle`).
enum PhotosAppearance: String {
    case system
    case light
    case dark

    var interfaceStyle: UIUserInterfaceStyle {
        switch self {
        case .system: return .unspecified
        case .light: return .light
        case .dark: return .dark
        }
    }
}

final class PhotosSettings: ObservableObject {
    static let shared = PhotosSettings()

    static let appearanceKey = "OldPhotos.Appearance"

    @Published private(set) var appearance: PhotosAppearance = .system
    private var observer: NSObjectProtocol?

    private init() {
        UserDefaults.standard.register(defaults: [Self.appearanceKey: PhotosAppearance.system.rawValue])
        read()
        observer = NotificationCenter.default.addObserver(
            forName: UserDefaults.didChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.read()
            self?.apply()
        }
    }

    private func read() {
        let value = PhotosAppearance(rawValue: UserDefaults.standard.string(forKey: Self.appearanceKey) ?? "") ?? .system
        if value != appearance { appearance = value }
    }

    /// Applied to every window, so keyboard, alerts and system sheets follow.
    func apply() {
        let style = appearance.interfaceStyle
        let windows = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
        for window in windows where window.overrideUserInterfaceStyle != style {
            window.overrideUserInterfaceStyle = style
        }
    }
}

/// The black translucent iOS 6 chrome always uses the light status bar; it
/// disappears with the bars in the full-screen viewer, like on iOS 6.
final class PhotosStatusBar: ObservableObject {
    static let shared = PhotosStatusBar()

    @Published var hidden = false

    private init() {}
}
