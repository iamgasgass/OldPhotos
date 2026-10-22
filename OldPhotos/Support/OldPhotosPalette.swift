import SwiftUI

// MARK: - Button families

/// OldOS `tool_bar_button_type`.
enum OldOSButtonType {
    case gray
    case blueGray
    case blue
    case black
    case red
}

/// OldOS `returnLinearGradient(_:)`, values copied 1:1.
func oldOSButtonGradient(_ type: OldOSButtonType) -> LinearGradient {
    switch type {
    case .gray:
        return LinearGradient(oldOS: [
            OldOSStop(.oldOS(164, 175, 191), 0),
            OldOSStop(.oldOS(124, 141, 164), 0.51),
            OldOSStop(.oldOS(113, 131, 156), 0.51),
            OldOSStop(.oldOS(112, 130, 155), 1)
        ])
    case .blueGray:
        return LinearGradient(oldOS: [
            OldOSStop(.oldOS(142, 166, 196), 0),
            OldOSStop(.oldOS(88, 119, 166), 0.50),
            OldOSStop(.oldOS(71, 105, 153), 0.533),
            OldOSStop(.oldOS(74, 108, 155), 1)
        ])
    case .blue:
        return LinearGradient(oldOS: [
            OldOSStop(.oldOS(137, 173, 238), 0),
            OldOSStop(.oldOS(80, 140, 231), 0.51),
            OldOSStop(.oldOS(43, 120, 228), 0.52),
            OldOSStop(.oldOS(46, 123, 229), 1)
        ])
    case .black:
        return LinearGradient(oldOS: [
            OldOSStop(.oldOS(95, 95, 95), 0),
            OldOSStop(.oldOS(32, 32, 32), 0.51),
            OldOSStop(.oldOS(7.5, 7.5, 7.5), 0.51),
            OldOSStop(.oldOS(7.5, 7.5, 7.5), 1)
        ])
    case .red:
        return LinearGradient(oldOS: [
            OldOSStop(.oldOS(239, 135, 142), 0),
            OldOSStop(.oldOS(199, 52, 63), 0.48),
            OldOSStop(.oldOS(189, 20, 33), 0.49),
            OldOSStop(.oldOS(189, 20, 33), 1)
        ])
    }
}

// MARK: - Theme

/// The colours of the OldPhotos tables in the two skins: the stock OldOS
/// white tables (Light) and OldSafari's Private Browsing graphite (Dark).
/// The black translucent iOS 6 Photos chrome is identical in both skins,
/// exactly as on iOS 6.
struct OldPhotosTheme {
    let isDark: Bool
    let listBackground: Color
    let listTopBounce: Color
    let listRowText: Color
    let listRowDetail: Color
    let listSeparator: Color
    let gridBackground: Color
    let gridFooterText: Color
    let thumbnailGlow: Color
    let emptyText: Color

    static func theme(isDark: Bool) -> OldPhotosTheme {
        isDark ? .dark : .standard
    }

    static let standard = OldPhotosTheme(
        isDark: false,
        listBackground: .white,
        listTopBounce: .oldOS(227, 231, 236),
        listRowText: .black,
        listRowDetail: .oldOS(127, 127, 127),
        listSeparator: .oldOS(224, 224, 224),
        gridBackground: .white,
        gridFooterText: .oldOSLightGray,
        thumbnailGlow: Color.gray.opacity(0.8),
        emptyText: .oldOS(98, 106, 121)
    )

    /// OldSafari Private Browsing values.
    static let dark = OldPhotosTheme(
        isDark: true,
        listBackground: .oldOS(30, 30, 32),
        listTopBounce: .oldOS(44, 46, 50),
        listRowText: .white,
        listRowDetail: .oldOS(150, 150, 154),
        listSeparator: Color.white.opacity(0.09),
        gridBackground: .oldOS(20, 20, 22),
        gridFooterText: .oldOS(150, 150, 154),
        thumbnailGlow: Color.black.opacity(0.8),
        emptyText: .oldOS(198, 202, 210)
    )
}

private struct OldPhotosThemeKey: EnvironmentKey {
    static let defaultValue: OldPhotosTheme = .standard
}

extension EnvironmentValues {
    var oldPhotosTheme: OldPhotosTheme {
        get { self[OldPhotosThemeKey.self] }
        set { self[OldPhotosThemeKey.self] = newValue }
    }
}

/// The black iOS 6 Photos chrome (`photos_title_bar`, `photo_destination_tool_bar`,
/// `PhotosTabView`), identical in Light and Dark.
enum OldPhotosBlackChrome {
    /// Translucent title bar / viewer toolbar (drawn at 65% opacity).
    static let translucentBar: [OldOSStop] = [
        OldOSStop(.oldOS(0, 0, 0), 0),
        OldOSStop(.oldOS(84, 84, 84), 0.005),
        OldOSStop(.oldOS(59, 59, 59), 0.04),
        OldOSStop(.oldOS(29, 29, 29), 0.5),
        OldOSStop(.oldOS(7.5, 7.5, 7.5), 0.51),
        OldOSStop(.oldOS(7.5, 7.5, 7.5), 1)
    ]
    static let translucentOpacity = 0.65
    static let hairline = Color.oldOS(45, 48, 51)
    static let highlight = Color.oldOS(230, 230, 230)

    /// Opaque tab bar.
    static let tabBar: [OldOSStop] = [
        OldOSStop(.oldOS(0, 0, 0), 0),
        OldOSStop(.oldOS(84, 84, 84), 0.02),
        OldOSStop(.oldOS(59, 59, 59), 0.04),
        OldOSStop(.oldOS(29, 29, 29), 0.5),
        OldOSStop(.oldOS(7.5, 7.5, 7.5), 0.51),
        OldOSStop(.oldOS(7.5, 7.5, 7.5), 1)
    ]
    static let tabBarBottom = Color.oldOS(7.5, 7.5, 7.5)
}
