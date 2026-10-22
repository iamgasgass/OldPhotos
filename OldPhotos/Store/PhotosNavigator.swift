import SwiftUI
import Photos

/// An iOS 6 action sheet request (`photo_video_share_view`, Delete…).
struct PhotosSheetRequest: Identifiable {
    let id = UUID()
    var title: String? = nil
    let buttons: [PhotosSheetButton]
}

struct PhotosSheetButton: Identifiable {
    let id = UUID()
    let title: String
    var destructive: Bool = false
    let action: () -> Void
}

/// A system sheet presented over the app (share sheet, Mail, Messages).
enum PhotosSystemSheet: Identifiable {
    case share([Any])
    case mail(PhotosAttachment)
    case message(PhotosAttachment)

    var id: String {
        switch self {
        case .share: return "share"
        case .mail: return "mail"
        case .message: return "message"
        }
    }
}

/// The state OldOS kept in `Photos` as strings (`current_nav_view`,
/// `switcher_current_nav_view`, `selectedTab`, `hide_bars`…).
final class PhotosNavigator: ObservableObject {
    @Published var tab: PhotosTab = .albums
    /// The grid pushed on Albums (`current_nav_view = "Camera Roll"`).
    @Published private(set) var albumsGrid: PhotosAlbum?
    /// The grid pushed on Places (photos of a pin).
    @Published private(set) var placesGrid: PhotosAlbum?
    /// The full-screen photo (`switcher_current_nav_view = "Destination"`).
    @Published private(set) var viewer: PhotosViewerRequest?
    /// `forward_or_backward`.
    @Published private(set) var movingForward = true
    /// `hide_bars`.
    @Published var hideBars = false

    /// iOS 6 grid selection mode (the action button of the grid).
    @Published var selecting = false
    @Published var selection: [String] = []

    @Published var sheet: PhotosSheetRequest?
    @Published var systemSheet: PhotosSystemSheet?

    private let lastTabKey = "OldPhotos.LastTab"

    init() {
        if let raw = UserDefaults.standard.string(forKey: lastTabKey), let saved = PhotosTab(rawValue: raw) {
            tab = saved
        }
    }

    var currentGrid: PhotosAlbum? {
        tab == .albums ? albumsGrid : placesGrid
    }

    func select(_ newTab: PhotosTab) {
        guard newTab != tab else {
            if currentGrid != nil { popGrid() }
            return
        }
        endSelection()
        withAnimation(nil) { tab = newTab }
        UserDefaults.standard.set(newTab.rawValue, forKey: lastTabKey)
    }

    func open(_ album: PhotosAlbum) {
        movingForward = true
        withAnimation(.linear(duration: 0.28)) {
            if tab == .albums {
                albumsGrid = album
            } else {
                placesGrid = album
            }
        }
    }

    func popGrid() {
        endSelection()
        movingForward = false
        withAnimation(.linear(duration: 0.28)) {
            if tab == .albums {
                albumsGrid = nil
            } else {
                placesGrid = nil
            }
        }
    }

    func openViewer(_ album: PhotosAlbum, index: Int) {
        movingForward = true
        hideBars = false
        withAnimation(.linear(duration: 0.28)) {
            viewer = PhotosViewerRequest(album: album, startIndex: index)
        }
    }

    func closeViewer() {
        movingForward = false
        withAnimation(.linear(duration: 0.28)) {
            viewer = nil
            hideBars = false
        }
    }

    // MARK: Selection

    func beginSelection() {
        withAnimation(.easeOut(duration: 0.2)) {
            selection = []
            selecting = true
        }
    }

    func endSelection() {
        guard selecting else { return }
        withAnimation(.easeOut(duration: 0.2)) {
            selecting = false
            selection = []
        }
    }

    func toggle(_ identifier: String) {
        if let index = selection.firstIndex(of: identifier) {
            selection.remove(at: index)
        } else {
            selection.append(identifier)
        }
    }

    // MARK: Sheets

    func presentSheet(title: String? = nil, _ buttons: [PhotosSheetButton]) {
        withAnimation(.easeOut(duration: 0.3)) {
            sheet = PhotosSheetRequest(title: title, buttons: buttons)
        }
    }

    func dismissSheet() {
        withAnimation(.easeOut(duration: 0.3)) { sheet = nil }
    }
}
