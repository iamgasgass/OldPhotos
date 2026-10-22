import SwiftUI
import Photos

/// OldOS `camera_roll`: 4 columns of square thumbnails with the grey inner
/// glow, the video badge with the duration, "12 Photos, 3 Videos" at the
/// bottom, opened scrolled to the newest photo. In selection mode (the
/// action button) thumbnails get the iOS 6 check mark.
struct PhotosGridView: View {
    @Environment(\.oldPhotosTheme) private var theme
    @EnvironmentObject private var navigator: PhotosNavigator
    @ObservedObject private var library = PhotosLibrary.shared
    let album: PhotosAlbum
    let topInset: CGFloat
    let bottomPadding: CGFloat

    @State private var assets: PHFetchResult<PHAsset> = PHAsset.fetchAssets(withLocalIdentifiers: [], options: nil)
    @State private var photoCount = 0
    @State private var videoCount = 0
    @State private var didScroll = false

    private let columns = [
        GridItem(.flexible(minimum: 60)),
        GridItem(.flexible(minimum: 60)),
        GridItem(.flexible(minimum: 60)),
        GridItem(.flexible(minimum: 60))
    ]

    var body: some View {
        ZStack {
            theme.gridBackground
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVGrid(columns: columns, spacing: 5) {
                        ForEach(0..<assets.count, id: \.self) { index in
                            cell(index)
                        }
                    }
                    .padding(8)
                    .padding(.top, topInset + 60)

                    HStack {
                        Spacer()
                        Text(footer)
                            .font(OldOSFont.regular(20))
                            .foregroundColor(theme.gridFooterText)
                            .lineLimit(1)
                        Spacer()
                    }
                    .padding(.bottom, 12 + bottomPadding)
                    .id("bottom_info")
                }
                .onAppear {
                    reload()
                    DispatchQueue.main.async {
                        proxy.scrollTo("bottom_info", anchor: .bottom)
                    }
                }
                .onChange(of: library.revision) { _ in
                    let previous = assets.count
                    reload()
                    if assets.count > previous {
                        withAnimation { proxy.scrollTo("bottom_info", anchor: .bottom) }
                    }
                }
            }
        }
    }

    private var footer: String {
        if assets.count == 0 && library.isLoaded {
            return "No Photos or Videos"
        }
        return "\(photoCount) \(photoCount == 1 ? "Photo" : "Photos"), \(videoCount) \(videoCount == 1 ? "Video" : "Videos")"
    }

    private func reload() {
        let result = album.fetchAssets()
        assets = result
        photoCount = result.countOfAssets(with: .image)
        videoCount = result.countOfAssets(with: .video)
        // Drop selections that no longer exist.
        if navigator.selecting {
            let present = Set((0..<result.count).map { result.object(at: $0).localIdentifier })
            navigator.selection.removeAll { !present.contains($0) }
        }
    }

    @ViewBuilder
    private func cell(_ index: Int) -> some View {
        if index < assets.count {
            let asset = assets.object(at: index)
            let selected = navigator.selection.contains(asset.localIdentifier)
            GeometryReader { proxy in
                Button {
                    if navigator.selecting {
                        OldPhotosHaptics.tap()
                        navigator.toggle(asset.localIdentifier)
                    } else {
                        navigator.openViewer(album, index: index)
                    }
                } label: {
                    PhotosThumbnail(asset: asset, side: proxy.size.width)
                        .frame(width: proxy.size.width, height: proxy.size.width)
                        .clipped()
                        .overlay(videoBadge(asset, size: proxy.size))
                        .overlay(selectionOverlay(selected))
                }
                .buttonStyle(.plain)
            }
            .clipped()
            .oldOSInnerShadowFull(color: theme.thumbnailGlow, radius: 0.02)
            .aspectRatio(1, contentMode: .fit)
            .id(asset.localIdentifier)
        }
    }

    @ViewBuilder
    private func videoBadge(_ asset: PHAsset, size: CGSize) -> some View {
        if asset.mediaType == .video {
            VStack {
                Spacer()
                ZStack {
                    Rectangle().fill(Color.black.opacity(0.5)).frame(width: size.width, height: size.height / 5)
                    HStack {
                        Image("GridVideoBadge").padding(.leading, 4)
                        Spacer()
                        Text(oldPhotosDuration(asset.duration))
                            .font(OldOSFont.bold(11))
                            .foregroundColor(.white)
                            .padding(.trailing, 4)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func selectionOverlay(_ selected: Bool) -> some View {
        if navigator.selecting && selected {
            ZStack(alignment: .bottomTrailing) {
                Color.white.opacity(0.3)
                PhotosCheckmark()
                    .frame(width: 24, height: 24)
                    .padding(3)
            }
        }
    }
}

/// The iOS 6 selection check: a glossy blue disc with a white tick.
struct PhotosCheckmark: View {
    var body: some View {
        ZStack {
            Circle()
                .fill(LinearGradient(oldOS: [
                    OldOSStop(.oldOS(105, 160, 245), 0),
                    OldOSStop(.oldOS(38, 104, 220), 0.5),
                    OldOSStop(.oldOS(22, 86, 205), 0.5),
                    OldOSStop(.oldOS(30, 98, 214), 1)
                ]))
            Circle().stroke(Color.white, lineWidth: 2)
            GeometryReader { geometry in
                let w = geometry.size.width
                Path { path in
                    path.move(to: CGPoint(x: w * 0.27, y: w * 0.52))
                    path.addLine(to: CGPoint(x: w * 0.44, y: w * 0.69))
                    path.addLine(to: CGPoint(x: w * 0.74, y: w * 0.34))
                }
                .stroke(Color.white, style: StrokeStyle(lineWidth: w * 0.12, lineCap: .round, lineJoin: .round))
            }
        }
        .shadow(color: Color.black.opacity(0.5), radius: 1, x: 0, y: 1)
    }
}

/// Selection mode bottom bar: Share and Delete (iOS 6).
struct PhotosSelectionBar: View {
    @EnvironmentObject private var navigator: PhotosNavigator
    let bottomInset: CGFloat

    var body: some View {
        let count = navigator.selection.count
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                PhotosBarButton(title: count == 0 ? "Share" : "Share (\(count))", type: .black) {
                    share()
                }
                .opacity(count == 0 ? 0.5 : 1)
                .disabled(count == 0)
                Spacer()
                PhotosBarButton(title: count == 0 ? "Delete" : "Delete (\(count))", type: .red) {
                    delete()
                }
                .opacity(count == 0 ? 0.5 : 1)
                .disabled(count == 0)
            }
            .padding(.horizontal, 8)
            .frame(height: 44)
            Color.clear.frame(height: bottomInset)
        }
        .background(PhotosToolbarBackground())
    }

    private var assets: [PHAsset] {
        let result = PHAsset.fetchAssets(withLocalIdentifiers: navigator.selection, options: nil)
        var list: [PHAsset] = []
        result.enumerateObjects { asset, _, _ in list.append(asset) }
        return list
    }

    private func share() {
        PhotosActions.share(assets, navigator: navigator)
    }

    private func delete() {
        PhotosActions.confirmDelete(assets, navigator: navigator) {
            navigator.endSelection()
        }
    }
}
