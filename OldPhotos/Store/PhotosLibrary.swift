import SwiftUI
import Photos
import CoreLocation

/// OldOS `PhotosObserver`, rebuilt:
/// - asks for permission (OldOS never did and showed an empty roll);
/// - keeps the `PHFetchResult` instead of appending 50 000 assets one by one
///   on the main thread (the OldOS 50k cap and its slow start are gone);
/// - follows library changes live (new shots, deletions, other apps);
/// - also lists the device albums and the Places pins.
final class PhotosLibrary: NSObject, ObservableObject, PHPhotoLibraryChangeObserver {
    static let shared = PhotosLibrary()

    enum Access {
        case unknown
        case granted
        case limited
        case denied
    }

    @Published private(set) var access: Access = .unknown
    @Published private(set) var cameraRoll: PHFetchResult<PHAsset> = PHAsset.fetchAssets(withLocalIdentifiers: [], options: nil)
    @Published private(set) var photoCount = 0
    @Published private(set) var videoCount = 0
    @Published private(set) var albums: [PhotosAlbumSummary] = []
    @Published private(set) var places: [PhotosPlace] = []
    @Published private(set) var isLoaded = false
    /// Bumped on every library change, so open grids / viewers refetch.
    @Published private(set) var revision = 0

    private let queue = DispatchQueue(label: "com.iamgasgass.oldphotos.library", qos: .userInitiated)
    private var registered = false
    private var generation = 0

    private override init() {
        super.init()
    }

    var canRead: Bool {
        access == .granted || access == .limited
    }

    // MARK: Authorization

    func start() {
        let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        if status == .notDetermined {
            PHPhotoLibrary.requestAuthorization(for: .readWrite) { [weak self] _ in
                DispatchQueue.main.async { self?.reload() }
            }
        } else {
            reload()
        }
    }

    private func updateAccess() {
        switch PHPhotoLibrary.authorizationStatus(for: .readWrite) {
        case .authorized: access = .granted
        case .limited: access = .limited
        case .notDetermined: access = .unknown
        default: access = .denied
        }
    }

    // MARK: Loading

    func reload() {
        updateAccess()
        guard canRead else {
            isLoaded = true
            return
        }
        if !registered {
            PHPhotoLibrary.shared().register(self)
            registered = true
        }
        generation += 1
        let current = generation

        // Roll, counts and albums first (what the screens need right away),
        // then the Places pins, which read every asset's location.
        queue.async { [weak self] in
            let roll = PhotosAlbum.cameraRoll.fetchAssets()
            let photos = roll.countOfAssets(with: .image)
            let videos = roll.countOfAssets(with: .video)
            let albums = Self.fetchAlbums()
            DispatchQueue.main.async {
                guard let self, current == self.generation else { return }
                self.cameraRoll = roll
                self.photoCount = photos
                self.videoCount = videos
                if self.albums != albums { self.albums = albums }
                self.isLoaded = true
                self.revision += 1
            }
            let places = Self.makePlaces(roll)
            DispatchQueue.main.async {
                guard let self, current == self.generation else { return }
                if self.places != places { self.places = places }
            }
        }
    }

    private var pendingChange: DispatchWorkItem?

    /// Bursts of changes (a shot being processed, iCloud syncing) are
    /// coalesced into one reload.
    func photoLibraryDidChange(_ changeInstance: PHChange) {
        DispatchQueue.main.async {
            self.pendingChange?.cancel()
            let work = DispatchWorkItem { [weak self] in self?.reload() }
            self.pendingChange = work
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25, execute: work)
        }
    }

    /// The device albums (iOS 6 listed them under Camera Roll).
    private static func fetchAlbums() -> [PhotosAlbumSummary] {
        var result: [PhotosAlbumSummary] = []
        let options = PHFetchOptions()
        options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: true)]
        options.predicate = NSPredicate(
            format: "mediaType == %d || mediaType == %d",
            PHAssetMediaType.image.rawValue,
            PHAssetMediaType.video.rawValue
        )

        func add(_ collection: PHAssetCollection) {
            let assets = PHAsset.fetchAssets(in: collection, options: options)
            guard assets.count > 0 else { return }
            let album = PhotosAlbum(
                id: collection.localIdentifier,
                title: collection.localizedTitle ?? "Album",
                kind: .collection(localIdentifier: collection.localIdentifier)
            )
            result.append(PhotosAlbumSummary(album: album, count: assets.count, keyAsset: assets.lastObject))
        }

        // Favorites, then the user's albums and shared albums.
        PHAssetCollection.fetchAssetCollections(with: .smartAlbum, subtype: .smartAlbumFavorites, options: nil)
            .enumerateObjects { collection, _, _ in add(collection) }
        PHAssetCollection.fetchAssetCollections(with: .album, subtype: .any, options: nil)
            .enumerateObjects { collection, _, _ in add(collection) }
        return result
    }

    /// OldOS dropped a pin for every unique location; photos are now grouped
    /// in ~1 km cells so a trip shows one pin per place instead of hundreds.
    private static func makePlaces(_ assets: PHFetchResult<PHAsset>) -> [PhotosPlace] {
        var cells: [String: (latitude: Double, longitude: Double, ids: [String])] = [:]
        var order: [String] = []
        assets.enumerateObjects { asset, _, _ in
            guard let location = asset.location else { return }
            let coordinate = location.coordinate
            guard CLLocationCoordinate2DIsValid(coordinate), coordinate.latitude != 0 || coordinate.longitude != 0 else { return }
            let key = String(format: "%.2f,%.2f", coordinate.latitude, coordinate.longitude)
            if var cell = cells[key] {
                cell.latitude += coordinate.latitude
                cell.longitude += coordinate.longitude
                cell.ids.append(asset.localIdentifier)
                cells[key] = cell
            } else {
                cells[key] = (coordinate.latitude, coordinate.longitude, [asset.localIdentifier])
                order.append(key)
            }
        }
        return order.compactMap { key in
            guard let cell = cells[key] else { return nil }
            let count = Double(cell.ids.count)
            return PhotosPlace(
                id: key,
                coordinate: CLLocationCoordinate2D(latitude: cell.latitude / count, longitude: cell.longitude / count),
                assetIdentifiers: cell.ids
            )
        }
    }

    // MARK: Editing

    /// Deletes assets; iOS shows its own confirmation, as it must.
    func delete(_ assets: [PHAsset], completion: ((Bool) -> Void)? = nil) {
        guard !assets.isEmpty else { return }
        PHPhotoLibrary.shared().performChanges({
            PHAssetChangeRequest.deleteAssets(assets as NSArray)
        }, completionHandler: { success, _ in
            DispatchQueue.main.async { completion?(success) }
        })
    }

    func asset(withIdentifier identifier: String) -> PHAsset? {
        PHAsset.fetchAssets(withLocalIdentifiers: [identifier], options: nil).firstObject
    }
}

// MARK: - Images

/// Thumbnail / full-size requests (OldOS `getImageData` / `getMainImage`
/// were synchronous and blocked the UI; these are asynchronous and cached).
enum PhotosImages {
    static let manager = PHCachingImageManager()

    @discardableResult
    static func thumbnail(for asset: PHAsset, side: CGFloat, completion: @escaping (UIImage?) -> Void) -> PHImageRequestID {
        let options = PHImageRequestOptions()
        options.deliveryMode = .opportunistic
        options.resizeMode = .fast
        options.isNetworkAccessAllowed = true
        let scale = UIScreen.main.scale
        return manager.requestImage(
            for: asset,
            targetSize: CGSize(width: side * scale, height: side * scale),
            contentMode: .aspectFill,
            options: options
        ) { image, _ in
            completion(image)
        }
    }

    /// Screen-size options, shared by the viewer requests and the
    /// neighbour pre-caching so the cache is actually hit.
    static let screenOptions: PHImageRequestOptions = {
        let options = PHImageRequestOptions()
        options.deliveryMode = .opportunistic
        options.resizeMode = .fast
        options.isNetworkAccessAllowed = true
        return options
    }()

    /// The viewer's page size in pixels.
    static var screenTarget: CGSize {
        let bounds = UIScreen.main.bounds.size
        let scale = UIScreen.main.scale
        return CGSize(width: bounds.width * scale, height: bounds.height * scale)
    }

    /// Screen-size image for a page (cached, pre-fetched for neighbours).
    @discardableResult
    static func screenImage(for asset: PHAsset, completion: @escaping (UIImage?, Bool) -> Void) -> PHImageRequestID {
        manager.requestImage(for: asset, targetSize: screenTarget, contentMode: .aspectFit, options: screenOptions) { image, info in
            let degraded = (info?[PHImageResultIsDegradedKey] as? Bool) ?? false
            completion(image, degraded)
        }
    }

    /// Full-detail image, requested only once the photo is zoomed.
    @discardableResult
    static func image(for asset: PHAsset, fitting size: CGSize, completion: @escaping (UIImage?, Bool) -> Void) -> PHImageRequestID {
        let options = PHImageRequestOptions()
        options.deliveryMode = .highQualityFormat
        options.resizeMode = .exact
        options.isNetworkAccessAllowed = true
        return PHImageManager.default().requestImage(
            for: asset,
            targetSize: size,
            contentMode: .aspectFit,
            options: options
        ) { image, info in
            let degraded = (info?[PHImageResultIsDegradedKey] as? Bool) ?? false
            completion(image, degraded)
        }
    }

    static func startCaching(_ assets: [PHAsset]) {
        guard !assets.isEmpty else { return }
        manager.startCachingImages(for: assets, targetSize: screenTarget, contentMode: .aspectFit, options: screenOptions)
    }

    static func stopCaching(_ assets: [PHAsset]) {
        guard !assets.isEmpty else { return }
        manager.stopCachingImages(for: assets, targetSize: screenTarget, contentMode: .aspectFit, options: screenOptions)
    }

    static func cancel(_ id: PHImageRequestID) {
        manager.cancelImageRequest(id)
        PHImageManager.default().cancelImageRequest(id)
    }
}
