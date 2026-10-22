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

        queue.async { [weak self] in
            let roll = PhotosAlbum.cameraRoll.fetchAssets()
            let photos = roll.countOfAssets(with: .image)
            let videos = roll.countOfAssets(with: .video)
            let albums = Self.fetchAlbums()
            let places = Self.makePlaces(roll)
            DispatchQueue.main.async {
                guard let self, current == self.generation else { return }
                self.cameraRoll = roll
                self.photoCount = photos
                self.videoCount = videos
                self.albums = albums
                self.places = places
                self.isLoaded = true
                self.revision += 1
            }
        }
    }

    func photoLibraryDidChange(_ changeInstance: PHChange) {
        DispatchQueue.main.async { self.reload() }
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
            result.append(PhotosAlbumSummary(album: album, count: assets.count, keyAssetIdentifier: assets.lastObject?.localIdentifier))
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

    @discardableResult
    static func image(for asset: PHAsset, fitting size: CGSize, completion: @escaping (UIImage?, Bool) -> Void) -> PHImageRequestID {
        let options = PHImageRequestOptions()
        options.deliveryMode = .opportunistic
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

    static func cancel(_ id: PHImageRequestID) {
        manager.cancelImageRequest(id)
        PHImageManager.default().cancelImageRequest(id)
    }
}
