import SwiftUI
import UIKit
import Photos

/// OldOS `camera_roll`: 4 columns of square thumbnails with the grey inner
/// glow, the video badge with the duration, "12 Photos, 3 Videos" at the
/// bottom, opened scrolled to the newest photo. In selection mode (the
/// action button) thumbnails get the iOS 6 check mark.
///
/// Same layout as the OldOS `LazyVGrid` (4 flexible columns, 8pt column
/// spacing, 5pt row spacing, 8pt padding), drawn by a `UICollectionView`
/// with cached, prefetched thumbnails so large libraries scroll smoothly.
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
    @State private var loaded = false

    var body: some View {
        ZStack {
            theme.gridBackground
            PhotosGridCollection(
                assets: assets,
                footer: footer,
                selecting: navigator.selecting,
                selection: Set(navigator.selection),
                topInset: topInset,
                bottomPadding: bottomPadding,
                background: UIColor(theme.gridBackground),
                footerColor: UIColor(theme.gridFooterText),
                glowColor: UIColor(theme.thumbnailGlow),
                onTap: { index in
                    open(index)
                }
            )
        }
        .onAppear {
            if !loaded { reload() }
        }
        .onChange(of: library.revision) { _ in
            reload()
        }
    }

    private var footer: String {
        if assets.count == 0 && library.isLoaded {
            return "No Photos or Videos"
        }
        return "\(photoCount) \(photoCount == 1 ? "Photo" : "Photos"), \(videoCount) \(videoCount == 1 ? "Video" : "Videos")"
    }

    private func reload() {
        loaded = true
        let result = album.fetchAssets()
        assets = result
        photoCount = result.countOfAssets(with: .image)
        videoCount = result.countOfAssets(with: .video)
        // Drop selections that no longer exist.
        if navigator.selecting, !navigator.selection.isEmpty {
            let present = PHAsset.fetchAssets(withLocalIdentifiers: navigator.selection, options: nil)
            var ids = Set<String>()
            present.enumerateObjects { asset, _, _ in ids.insert(asset.localIdentifier) }
            navigator.selection.removeAll { !ids.contains($0) }
        }
    }

    private func open(_ index: Int) {
        guard index < assets.count else { return }
        if navigator.selecting {
            OldPhotosHaptics.tap()
            navigator.toggle(assets.object(at: index).localIdentifier)
        } else {
            navigator.openViewer(album, index: index)
        }
    }
}

// MARK: - Collection view

struct PhotosGridCollection: UIViewRepresentable {
    let assets: PHFetchResult<PHAsset>
    let footer: String
    let selecting: Bool
    let selection: Set<String>
    let topInset: CGFloat
    let bottomPadding: CGFloat
    let background: UIColor
    let footerColor: UIColor
    let glowColor: UIColor
    let onTap: (Int) -> Void

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> UICollectionView {
        let layout = UICollectionViewFlowLayout()
        layout.minimumInteritemSpacing = PhotosGridMetrics.columnSpacing
        layout.minimumLineSpacing = PhotosGridMetrics.rowSpacing
        let collection = UICollectionView(frame: .zero, collectionViewLayout: layout)
        collection.contentInsetAdjustmentBehavior = .never
        collection.showsHorizontalScrollIndicator = false
        collection.alwaysBounceVertical = true
        collection.register(PhotosGridCell.self, forCellWithReuseIdentifier: PhotosGridCell.reuseID)
        collection.register(PhotosGridFooter.self, forSupplementaryViewOfKind: UICollectionView.elementKindSectionFooter, withReuseIdentifier: PhotosGridFooter.reuseID)
        collection.dataSource = context.coordinator
        collection.delegate = context.coordinator
        collection.prefetchDataSource = context.coordinator
        context.coordinator.collection = collection
        return collection
    }

    func updateUIView(_ collection: UICollectionView, context: Context) {
        let coordinator = context.coordinator
        coordinator.onTap = onTap
        collection.backgroundColor = background

        let assetsChanged = coordinator.assets !== assets
        let previousCount = coordinator.assets?.count ?? 0
        let styleChanged = coordinator.footer != footer
            || coordinator.footerColor != footerColor
            || coordinator.glowColor != glowColor
            || coordinator.topInset != topInset
            || coordinator.bottomPadding != bottomPadding
        let selectionChanged = coordinator.selecting != selecting || coordinator.selection != selection

        coordinator.assets = assets
        coordinator.footer = footer
        coordinator.footerColor = footerColor
        coordinator.glowColor = glowColor
        coordinator.topInset = topInset
        coordinator.bottomPadding = bottomPadding
        coordinator.selecting = selecting
        coordinator.selection = selection

        if assetsChanged || styleChanged {
            coordinator.resetCaching()
            collection.reloadData()
            collection.collectionViewLayout.invalidateLayout()
            if assetsChanged && (!coordinator.didInitialScroll || assets.count > previousCount) {
                let animated = coordinator.didInitialScroll
                DispatchQueue.main.async {
                    coordinator.scrollToBottom(animated: animated)
                }
            }
        } else if selectionChanged {
            for cell in collection.visibleCells {
                guard let cell = cell as? PhotosGridCell,
                      let indexPath = collection.indexPath(for: cell) else { continue }
                coordinator.applySelection(cell, at: indexPath.item)
            }
        }
    }

    final class Coordinator: NSObject, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout, UICollectionViewDataSourcePrefetching {
        weak var collection: UICollectionView?
        var assets: PHFetchResult<PHAsset>?
        var footer = ""
        var footerColor: UIColor = .lightGray
        var glowColor: UIColor = .gray
        var topInset: CGFloat = 0
        var bottomPadding: CGFloat = 0
        var selecting = false
        var selection: Set<String> = []
        var onTap: ((Int) -> Void)?
        var didInitialScroll = false

        private let cache = PHCachingImageManager()

        override init() {
            super.init()
            cache.allowsCachingHighQualityImages = false
        }

        // Layout

        private func itemSide(for width: CGFloat) -> CGFloat {
            let usable = width - PhotosGridMetrics.padding * 2 - PhotosGridMetrics.columnSpacing * CGFloat(PhotosGridMetrics.columns - 1)
            return floor(max(usable, 60) / CGFloat(PhotosGridMetrics.columns) * 2) / 2
        }

        private var thumbnailSize: CGSize {
            let side = itemSide(for: collection?.bounds.width ?? UIScreen.main.bounds.width) * UIScreen.main.scale
            return CGSize(width: side, height: side)
        }

        func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
            let side = itemSide(for: collectionView.bounds.width)
            return CGSize(width: side, height: side)
        }

        func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, insetForSectionAt section: Int) -> UIEdgeInsets {
            UIEdgeInsets(top: PhotosGridMetrics.padding + topInset + 60, left: PhotosGridMetrics.padding, bottom: PhotosGridMetrics.padding, right: PhotosGridMetrics.padding)
        }

        func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, referenceSizeForFooterInSection section: Int) -> CGSize {
            CGSize(width: collectionView.bounds.width, height: PhotosGridFooter.labelHeight + 12 + bottomPadding)
        }

        // Data

        func numberOfSections(in collectionView: UICollectionView) -> Int { 1 }

        func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
            assets?.count ?? 0
        }

        func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
            // swiftlint:disable:next force_cast
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: PhotosGridCell.reuseID, for: indexPath) as! PhotosGridCell
            guard let assets, indexPath.item < assets.count else { return cell }
            let asset = assets.object(at: indexPath.item)
            cell.configure(asset: asset, glow: glowColor)
            applySelection(cell, at: indexPath.item)

            let identifier = asset.localIdentifier
            let options = PHImageRequestOptions()
            options.deliveryMode = .opportunistic
            options.resizeMode = .fast
            options.isNetworkAccessAllowed = true
            cell.requestID = cache.requestImage(for: asset, targetSize: thumbnailSize, contentMode: .aspectFill, options: options) { [weak cell] image, _ in
                guard let cell, cell.representedID == identifier, let image else { return }
                cell.imageView.image = image
            }
            return cell
        }

        func collectionView(_ collectionView: UICollectionView, viewForSupplementaryElementOfKind kind: String, at indexPath: IndexPath) -> UICollectionReusableView {
            // swiftlint:disable:next force_cast
            let view = collectionView.dequeueReusableSupplementaryView(ofKind: kind, withReuseIdentifier: PhotosGridFooter.reuseID, for: indexPath) as! PhotosGridFooter
            view.label.text = footer
            view.label.textColor = footerColor
            return view
        }

        func collectionView(_ collectionView: UICollectionView, didEndDisplaying cell: UICollectionViewCell, forItemAt indexPath: IndexPath) {
            guard let cell = cell as? PhotosGridCell, let id = cell.requestID else { return }
            cache.cancelImageRequest(id)
            cell.requestID = nil
        }

        func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
            collectionView.deselectItem(at: indexPath, animated: false)
            onTap?(indexPath.item)
        }

        // Prefetching (PHCachingImageManager)

        private func assets(at indexPaths: [IndexPath]) -> [PHAsset] {
            guard let assets else { return [] }
            return indexPaths.compactMap { $0.item < assets.count ? assets.object(at: $0.item) : nil }
        }

        func collectionView(_ collectionView: UICollectionView, prefetchItemsAt indexPaths: [IndexPath]) {
            cache.startCachingImages(for: assets(at: indexPaths), targetSize: thumbnailSize, contentMode: .aspectFill, options: nil)
        }

        func collectionView(_ collectionView: UICollectionView, cancelPrefetchingForItemsAt indexPaths: [IndexPath]) {
            cache.stopCachingImages(for: assets(at: indexPaths), targetSize: thumbnailSize, contentMode: .aspectFill, options: nil)
        }

        func resetCaching() {
            cache.stopCachingImagesForAllAssets()
        }

        // Selection

        func applySelection(_ cell: PhotosGridCell, at index: Int) {
            guard let assets, index < assets.count else { return }
            cell.setChecked(selecting && selection.contains(assets.object(at: index).localIdentifier))
        }

        // Scrolling

        func scrollToBottom(animated: Bool, attempt: Int = 0) {
            guard let collection else { return }
            guard collection.bounds.height > 0 else {
                if attempt < 20 {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.02) {
                        self.scrollToBottom(animated: animated, attempt: attempt + 1)
                    }
                }
                return
            }
            collection.layoutIfNeeded()
            let height = collection.collectionViewLayout.collectionViewContentSize.height
            let offset = max(height - collection.bounds.height, 0)
            collection.setContentOffset(CGPoint(x: 0, y: offset), animated: animated)
            if (assets?.count ?? 0) > 0 { didInitialScroll = true }
        }
    }
}

enum PhotosGridMetrics {
    static let columns = 4
    static let columnSpacing: CGFloat = 8
    static let rowSpacing: CGFloat = 5
    static let padding: CGFloat = 8
}

/// A thumbnail: aspect-filled square, OldOS `innerShadowFull` glow on all
/// four edges, video badge with duration, iOS 6 check when selected.
final class PhotosGridCell: UICollectionViewCell {
    static let reuseID = "PhotosGridCell"

    let imageView = UIImageView()
    var representedID: String?
    var requestID: PHImageRequestID?

    private let glowLayers = (0..<4).map { _ in CAGradientLayer() }
    private let videoBar = UIView()
    private let videoIcon = UIImageView(image: UIImage(named: "GridVideoBadge"))
    private let durationLabel = UILabel()
    private let selectionTint = UIView()
    private let check = PhotosCheckView()

    override init(frame: CGRect) {
        super.init(frame: frame)
        contentView.clipsToBounds = true
        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
        contentView.addSubview(imageView)

        for layer in glowLayers {
            contentView.layer.addSublayer(layer)
        }

        videoBar.backgroundColor = UIColor.black.withAlphaComponent(0.5)
        videoBar.addSubview(videoIcon)
        durationLabel.font = OldOSFont.uiBold(11)
        durationLabel.textColor = .white
        durationLabel.textAlignment = .right
        videoBar.addSubview(durationLabel)
        contentView.addSubview(videoBar)

        selectionTint.backgroundColor = UIColor.white.withAlphaComponent(0.3)
        selectionTint.isHidden = true
        contentView.addSubview(selectionTint)
        check.isHidden = true
        contentView.addSubview(check)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        imageView.image = nil
        representedID = nil
    }

    func configure(asset: PHAsset, glow: UIColor) {
        representedID = asset.localIdentifier
        let isVideo = asset.mediaType == .video
        videoBar.isHidden = !isVideo
        if isVideo {
            durationLabel.text = oldPhotosDuration(asset.duration)
        }
        let strong = glow.withAlphaComponent(glow.cgColor.alpha * 0.75).cgColor
        let clear = glow.withAlphaComponent(0).cgColor
        for layer in glowLayers {
            layer.colors = [strong, clear, UIColor.clear.cgColor]
        }
        setNeedsLayout()
    }

    func setChecked(_ checked: Bool) {
        selectionTint.isHidden = !checked
        check.isHidden = !checked
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        let bounds = contentView.bounds
        imageView.frame = bounds

        // OldOS: radius 0.02 of 1.5 × the shortest side, on every edge.
        let side = CGFloat(3) * min(bounds.width, bounds.height) / 2 * 0.02
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        let (top, bottom, left, right) = (glowLayers[0], glowLayers[1], glowLayers[2], glowLayers[3])
        top.frame = CGRect(x: 0, y: 0, width: bounds.width, height: side)
        top.startPoint = CGPoint(x: 0.5, y: 0); top.endPoint = CGPoint(x: 0.5, y: 1)
        bottom.frame = CGRect(x: 0, y: bounds.height - side, width: bounds.width, height: side)
        bottom.startPoint = CGPoint(x: 0.5, y: 1); bottom.endPoint = CGPoint(x: 0.5, y: 0)
        left.frame = CGRect(x: 0, y: 0, width: side, height: bounds.height)
        left.startPoint = CGPoint(x: 0, y: 0.5); left.endPoint = CGPoint(x: 1, y: 0.5)
        right.frame = CGRect(x: bounds.width - side, y: 0, width: side, height: bounds.height)
        right.startPoint = CGPoint(x: 1, y: 0.5); right.endPoint = CGPoint(x: 0, y: 0.5)
        CATransaction.commit()

        let barHeight = bounds.height / 5
        videoBar.frame = CGRect(x: 0, y: bounds.height - barHeight, width: bounds.width, height: barHeight)
        let iconSize = videoIcon.image?.size ?? CGSize(width: 15, height: 8)
        videoIcon.frame = CGRect(x: 4, y: (barHeight - iconSize.height) / 2, width: iconSize.width, height: iconSize.height)
        durationLabel.frame = CGRect(x: 4, y: 0, width: bounds.width - 8, height: barHeight)

        selectionTint.frame = bounds
        check.frame = CGRect(x: bounds.width - 27, y: bounds.height - 27, width: 24, height: 24)
    }
}

/// The iOS 6 selection check: a glossy blue disc with a white tick.
final class PhotosCheckView: UIView {
    override init(frame: CGRect) {
        super.init(frame: frame)
        isOpaque = false
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOpacity = 0.5
        layer.shadowRadius = 1
        layer.shadowOffset = CGSize(width: 0, height: 1)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func draw(_ rect: CGRect) {
        guard let context = UIGraphicsGetCurrentContext() else { return }
        let circle = bounds.insetBy(dx: 1, dy: 1)
        context.saveGState()
        context.addEllipse(in: circle)
        context.clip()
        let colors = [
            UIColor(red: 105 / 255, green: 160 / 255, blue: 245 / 255, alpha: 1).cgColor,
            UIColor(red: 38 / 255, green: 104 / 255, blue: 220 / 255, alpha: 1).cgColor,
            UIColor(red: 22 / 255, green: 86 / 255, blue: 205 / 255, alpha: 1).cgColor,
            UIColor(red: 30 / 255, green: 98 / 255, blue: 214 / 255, alpha: 1).cgColor
        ] as CFArray
        if let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: [0, 0.5, 0.5, 1]) {
            context.drawLinearGradient(gradient, start: CGPoint(x: 0, y: circle.minY), end: CGPoint(x: 0, y: circle.maxY), options: [])
        }
        context.restoreGState()

        UIColor.white.setStroke()
        let ring = UIBezierPath(ovalIn: circle)
        ring.lineWidth = 2
        ring.stroke()

        let w = bounds.width
        let tick = UIBezierPath()
        tick.move(to: CGPoint(x: w * 0.27, y: w * 0.52))
        tick.addLine(to: CGPoint(x: w * 0.44, y: w * 0.69))
        tick.addLine(to: CGPoint(x: w * 0.74, y: w * 0.34))
        tick.lineWidth = w * 0.12
        tick.lineCapStyle = .round
        tick.lineJoinStyle = .round
        tick.stroke()
    }
}

/// "12 Photos, 3 Videos".
final class PhotosGridFooter: UICollectionReusableView {
    static let reuseID = "PhotosGridFooter"
    static let labelHeight: CGFloat = 24

    let label = UILabel()

    override init(frame: CGRect) {
        super.init(frame: frame)
        label.font = OldOSFont.uiRegular(20)
        label.textAlignment = .center
        label.adjustsFontSizeToFitWidth = true
        label.minimumScaleFactor = 0.7
        addSubview(label)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        label.frame = CGRect(x: 8, y: 0, width: bounds.width - 16, height: Self.labelHeight)
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
