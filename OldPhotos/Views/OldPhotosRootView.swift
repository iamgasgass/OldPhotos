import SwiftUI
import Photos

/// OldOS `Photos`: Albums / Places with the black translucent title bar
/// laid over the content and the black tab bar, and the full-screen viewer
/// sliding in over everything. Bars extend behind the status bar / Dynamic
/// Island and the home indicator, exactly like OldSafari.
struct OldPhotosRootView: View {
    @Environment(\.colorScheme) private var colorScheme
    @StateObject private var navigator = PhotosNavigator()
    @StateObject private var safeArea = OldOSSafeArea()
    @ObservedObject private var library = PhotosLibrary.shared

    var body: some View {
        GeometryReader { geometry in
            let topInset = max(geometry.safeAreaInsets.top, safeArea.insets.top)
            let bottomInset = max(geometry.safeAreaInsets.bottom, safeArea.insets.bottom)

            ZStack {
                Color.black

                VStack(spacing: 0) {
                    ZStack(alignment: .top) {
                        content(topInset: topInset)
                            .id(screenID)
                            .transition(slide)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .clipped()

                        titleBar(topInset: topInset)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .clipped()

                    if navigator.selecting {
                        PhotosSelectionBar(bottomInset: bottomInset)
                            .transition(.move(edge: .bottom))
                    } else {
                        PhotosTabBar(bottomInset: bottomInset)
                    }
                }

                if let viewer = navigator.viewer {
                    PhotosViewerView(request: viewer, topInset: topInset, bottomInset: bottomInset)
                        .id(viewer.id)
                        .transition(.asymmetric(insertion: .move(edge: .trailing), removal: .move(edge: .trailing)))
                        .zIndex(10)
                }

                if let sheet = navigator.sheet {
                    PhotosActionSheet(
                        title: sheet.title,
                        buttons: sheet.buttons,
                        bottomInset: bottomInset,
                        onCancel: { navigator.dismissSheet() }
                    )
                    .id(sheet.id)
                    .transition(.opacity)
                    .zIndex(20)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .clipped()
            .onAppear { safeArea.refresh() }
        }
        .ignoresSafeArea()
        .environment(\.oldPhotosTheme, OldPhotosTheme.theme(isDark: colorScheme == .dark))
        .environmentObject(navigator)
        .sheet(item: $navigator.systemSheet) { sheet in
            switch sheet {
            case .share(let items):
                PhotosShareSheet(items: items)
            case .mail(let attachment):
                PhotosMailComposer(attachment: attachment).ignoresSafeArea()
            case .message(let attachment):
                PhotosMessageComposer(attachment: attachment).ignoresSafeArea()
            }
        }
        .onAppear {
            PhotosSettings.shared.apply()
            library.start()
        }
        .onChange(of: navigator.hideBars) { _ in updateStatusBar() }
        .onChange(of: navigator.viewer) { _ in updateStatusBar() }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
            // Permission may have been changed in Settings meanwhile.
            library.reload()
        }
    }

    private var screenID: String {
        "\(navigator.tab.rawValue)-\(navigator.currentGrid?.id ?? "root")"
    }

    private var slide: AnyTransition {
        let forward = navigator.movingForward
        return .asymmetric(
            insertion: .move(edge: forward ? .trailing : .leading),
            removal: .move(edge: forward ? .leading : .trailing)
        )
    }

    private func updateStatusBar() {
        PhotosStatusBar.shared.hidden = navigator.viewer != nil && navigator.hideBars
    }

    // MARK: Content

    @ViewBuilder
    private func content(topInset: CGFloat) -> some View {
        if let grid = navigator.currentGrid {
            PhotosGridView(album: grid, topInset: topInset, bottomPadding: 0)
        } else {
            switch navigator.tab {
            case .albums:
                PhotosAlbumsView(topInset: topInset)
            case .places:
                PhotosPlacesView(topInset: topInset)
            }
        }
    }

    // MARK: Title bar (`photos_title_bar`)

    @ViewBuilder
    private func titleBar(topInset: CGFloat) -> some View {
        if let grid = navigator.currentGrid {
            PhotosTitleBar(
                title: navigator.selecting ? selectionTitle : grid.title,
                topInset: topInset,
                forward: navigator.movingForward
            ) {
                if !navigator.selecting {
                    PhotosBackButton(title: navigator.tab.title) {
                        navigator.popGrid()
                    }
                    .transition(.opacity)
                }
            } trailing: {
                if navigator.selecting {
                    PhotosBarButton(title: "Cancel", type: .blue) {
                        navigator.endSelection()
                    }
                    .padding(.trailing, 8)
                } else {
                    PhotosBarButton(image: "BarAction", type: .black) {
                        navigator.beginSelection()
                    }
                    .padding(.trailing, 8)
                }
            }
        } else {
            PhotosTitleBar(title: navigator.tab.title, topInset: topInset, forward: navigator.movingForward) {
                EmptyView()
            } trailing: {
                EmptyView()
            }
        }
    }

    private var selectionTitle: String {
        let count = navigator.selection.count
        switch count {
        case 0: return "Select Items"
        case 1: return "1 Item Selected"
        default: return "\(count) Items Selected"
        }
    }
}
