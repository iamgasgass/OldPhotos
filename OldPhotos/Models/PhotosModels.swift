import Foundation
import Photos
import CoreLocation

/// OldOS `photos_tabs`.
enum PhotosTab: String, CaseIterable, Identifiable {
    case albums = "Albums"
    case places = "Places"

    var id: String { rawValue }
    var title: String { rawValue }
    var iconName: String { "Tab\(rawValue)" }
}

/// Something that opens as a thumbnail grid: Camera Roll (OldOS
/// `camera_roll`), one of the device albums, or the photos of a place.
struct PhotosAlbum: Identifiable, Equatable {
    enum Kind: Equatable {
        case cameraRoll
        case collection(localIdentifier: String)
        case place(assetIdentifiers: [String])
    }

    let id: String
    var title: String
    let kind: Kind

    static let cameraRoll = PhotosAlbum(id: "camera-roll", title: "Camera Roll", kind: .cameraRoll)

    /// The assets, oldest first (OldOS sorts by `creationDate` ascending and
    /// shows the newest at the bottom).
    func fetchAssets() -> PHFetchResult<PHAsset> {
        let options = PHFetchOptions()
        options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: true)]
        options.predicate = NSPredicate(
            format: "mediaType == %d || mediaType == %d",
            PHAssetMediaType.image.rawValue,
            PHAssetMediaType.video.rawValue
        )
        switch kind {
        case .cameraRoll:
            return PHAsset.fetchAssets(with: options)
        case .collection(let identifier):
            guard let collection = PHAssetCollection.fetchAssetCollections(withLocalIdentifiers: [identifier], options: nil).firstObject else {
                return PHAsset.fetchAssets(withLocalIdentifiers: [], options: nil)
            }
            return PHAsset.fetchAssets(in: collection, options: options)
        case .place(let identifiers):
            return PHAsset.fetchAssets(withLocalIdentifiers: identifiers, options: options)
        }
    }
}

/// A row of the Albums list.
struct PhotosAlbumSummary: Identifiable, Equatable {
    let album: PhotosAlbum
    let count: Int
    let keyAsset: PHAsset?

    var id: String { album.id }
}

/// A pin of the Places map: photos taken within the same ~1 km cell.
struct PhotosPlace: Identifiable, Equatable {
    let id: String
    let coordinate: CLLocationCoordinate2D
    let assetIdentifiers: [String]

    static func == (lhs: PhotosPlace, rhs: PhotosPlace) -> Bool {
        lhs.id == rhs.id && lhs.assetIdentifiers == rhs.assetIdentifiers
    }
}

/// The asset shown full screen (OldOS `photo_destination`).
struct PhotosViewerRequest: Identifiable, Equatable {
    let id = UUID()
    let album: PhotosAlbum
    let startIndex: Int
}
