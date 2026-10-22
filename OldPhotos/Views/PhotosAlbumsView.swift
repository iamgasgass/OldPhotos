import SwiftUI
import Photos

/// OldOS `photos_select_view`: "Camera Roll (123)" with the last photo as
/// thumbnail — plus, as on iOS 6, the device albums below it.
struct PhotosAlbumsView: View {
    @Environment(\.oldPhotosTheme) private var theme
    @EnvironmentObject private var navigator: PhotosNavigator
    @ObservedObject private var library = PhotosLibrary.shared
    let topInset: CGFloat

    var body: some View {
        ZStack {
            theme.listBackground
            if library.access == .denied {
                PhotosEmptyView(
                    title: "No Access to Photos",
                    message: "Allow OldPhotos to use your photos in Settings › Privacy & Security › Photos."
                )
                .onTapGesture {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                }
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        Color.clear.frame(height: topInset + 60)
                        PhotosAlbumRow(
                            title: PhotosAlbum.cameraRoll.title,
                            count: library.cameraRoll.count,
                            keyAsset: library.cameraRoll.lastObject
                        ) {
                            navigator.open(.cameraRoll)
                        }
                        ForEach(library.albums) { summary in
                            PhotosAlbumRow(
                                title: summary.album.title,
                                count: summary.count,
                                keyAsset: summary.keyAsset
                            ) {
                                navigator.open(summary.album)
                            }
                        }
                    }
                }
                .scrollIndicators(.hidden)
            }
        }
    }
}

/// A 60pt album row: thumbnail, bold name, grey "(count)", disclosure.
struct PhotosAlbumRow: View {
    @Environment(\.oldPhotosTheme) private var theme
    let title: String
    let count: Int
    let keyAsset: PHAsset?
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 0) {
                    PhotosThumbnail(asset: keyAsset, side: 60 - 0.95)
                        .frame(width: 60 - 0.95, height: 60 - 0.95)
                        .clipped()
                    (Text("\(title) ").font(OldOSFont.bold(16)).foregroundColor(theme.listRowText)
                        + Text("(\(count))").font(OldOSFont.regular(16)).foregroundColor(theme.listRowDetail))
                        .lineLimit(1)
                        .padding(.leading, 6)
                        .padding(.trailing, 40)
                    Spacer(minLength: 0)
                    Image("UITableNext").padding(.trailing, 12)
                }
                Rectangle().fill(theme.listSeparator).frame(height: 0.95)
            }
            .frame(height: 60)
            .contentShape(Rectangle())
        }
        .buttonStyle(PhotosRowButtonStyle())
    }
}

/// iOS 6 blue row highlight.
struct PhotosRowButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .overlay(
                LinearGradient(oldOS: [
                    OldOSStop(.oldOS(5, 140, 245), 0),
                    OldOSStop(.oldOS(1, 93, 230), 1)
                ])
                .opacity(configuration.isPressed ? 0.35 : 0)
                .allowsHitTesting(false)
            )
    }
}

/// A square, aspect-filled thumbnail loaded asynchronously.
struct PhotosThumbnail: View {
    let asset: PHAsset?
    let side: CGFloat

    @State private var image: UIImage?
    @State private var loadedID: String?
    @State private var requestID: PHImageRequestID?

    var body: some View {
        ZStack {
            Color.oldOS(200, 200, 200).opacity(image == nil ? 0.35 : 0)
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            }
        }
        .onAppear(perform: load)
        .onChange(of: asset?.localIdentifier) { _ in load() }
        .onDisappear {
            if let requestID { PhotosImages.cancel(requestID) }
        }
    }

    private func load() {
        guard let asset else {
            image = nil
            loadedID = nil
            return
        }
        guard loadedID != asset.localIdentifier || image == nil else { return }
        loadedID = asset.localIdentifier
        requestID = PhotosImages.thumbnail(for: asset, side: max(side, 40)) { result in
            if let result, loadedID == asset.localIdentifier {
                image = result
            }
        }
    }
}

/// iOS 6 empty / no access placeholder.
struct PhotosEmptyView: View {
    @Environment(\.oldPhotosTheme) private var theme
    let title: String
    var message: String? = nil

    var body: some View {
        ZStack {
            theme.listBackground
            VStack(spacing: 12) {
                Spacer()
                Text(title)
                    .font(OldOSFont.bold(20))
                    .foregroundColor(theme.emptyText)
                if let message {
                    Text(message)
                        .font(OldOSFont.bold(14))
                        .foregroundColor(theme.emptyText)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 30)
                }
                Spacer()
            }
        }
    }
}
