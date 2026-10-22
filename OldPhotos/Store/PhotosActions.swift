import SwiftUI
import Photos
import MessageUI
import AVFoundation

/// A photo / video ready to attach to Mail or Messages.
struct PhotosAttachment {
    let data: Data
    let mimeType: String
    let fileName: String
    let typeIdentifier: String
    let isVideo: Bool
}

/// The actions behind the OldOS share sheet (`photo_video_share_view`:
/// Email Photo / MMS / Send to YouTube — all inert in OldOS) and the trash
/// button, now working: Mail, Messages, Copy, the system share sheet, and
/// deleting from the library.
enum PhotosActions {

    // MARK: Export

    static func attachment(for asset: PHAsset, completion: @escaping (PhotosAttachment?) -> Void) {
        if asset.mediaType == .video {
            exportVideo(asset) { url in
                guard let url, let data = try? Data(contentsOf: url) else {
                    completion(nil)
                    return
                }
                completion(PhotosAttachment(data: data, mimeType: "video/quicktime", fileName: "Video.mov", typeIdentifier: "com.apple.quicktime-movie", isVideo: true))
            }
        } else {
            imageJPEG(asset) { data in
                guard let data else {
                    completion(nil)
                    return
                }
                completion(PhotosAttachment(data: data, mimeType: "image/jpeg", fileName: "Photo.jpg", typeIdentifier: "public.jpeg", isVideo: false))
            }
        }
    }

    /// Full-resolution JPEG of a photo (HEIC is converted for Mail / MMS).
    static func imageJPEG(_ asset: PHAsset, completion: @escaping (Data?) -> Void) {
        let options = PHImageRequestOptions()
        options.isNetworkAccessAllowed = true
        options.deliveryMode = .highQualityFormat
        options.version = .current
        PHImageManager.default().requestImageDataAndOrientation(for: asset, options: options) { data, _, _, _ in
            guard let data, let image = UIImage(data: data) else {
                DispatchQueue.main.async { completion(nil) }
                return
            }
            let jpeg = image.jpegData(compressionQuality: 0.9)
            DispatchQueue.main.async { completion(jpeg) }
        }
    }

    static func exportVideo(_ asset: PHAsset, completion: @escaping (URL?) -> Void) {
        let options = PHVideoRequestOptions()
        options.isNetworkAccessAllowed = true
        options.deliveryMode = .highQualityFormat
        PHImageManager.default().requestExportSession(forVideo: asset, options: options, exportPreset: AVAssetExportPresetHighestQuality) { session, _ in
            guard let session else {
                DispatchQueue.main.async { completion(nil) }
                return
            }
            let url = FileManager.default.temporaryDirectory.appendingPathComponent("Video-\(UUID().uuidString).mov")
            session.outputURL = url
            session.outputFileType = .mov
            session.exportAsynchronously {
                DispatchQueue.main.async {
                    completion(session.status == .completed ? url : nil)
                }
            }
        }
    }

    /// Files for the system share sheet (one per asset, in order).
    static func shareItems(for assets: [PHAsset], completion: @escaping ([Any]) -> Void) {
        var items = [Any?](repeating: nil, count: assets.count)
        let group = DispatchGroup()
        for (index, asset) in assets.enumerated() {
            group.enter()
            if asset.mediaType == .video {
                exportVideo(asset) { url in
                    items[index] = url
                    group.leave()
                }
            } else {
                imageJPEG(asset) { data in
                    if let data {
                        let url = FileManager.default.temporaryDirectory.appendingPathComponent("IMG_\(String(format: "%04d", index + 1)).JPG")
                        try? data.write(to: url, options: .atomic)
                        items[index] = url
                    }
                    group.leave()
                }
            }
        }
        group.notify(queue: .main) {
            completion(items.compactMap { $0 })
        }
    }

    // MARK: Sheets

    /// The viewer's action button: iOS 6 "Email Photo / Message / Copy …".
    static func presentShareOptions(for asset: PHAsset, navigator: PhotosNavigator) {
        let noun = asset.mediaType == .video ? "Video" : "Photo"
        var buttons: [PhotosSheetButton] = [
            PhotosSheetButton(title: "Email \(noun)") {
                navigator.dismissSheet()
                email([asset], navigator: navigator)
            },
            PhotosSheetButton(title: "Message") {
                navigator.dismissSheet()
                message([asset], navigator: navigator)
            }
        ]
        if asset.mediaType == .image {
            buttons.append(PhotosSheetButton(title: "Copy Photo") {
                navigator.dismissSheet()
                imageJPEG(asset) { data in
                    if let data, let image = UIImage(data: data) {
                        UIPasteboard.general.image = image
                        OldPhotosHaptics.tap()
                    }
                }
            })
        }
        buttons.append(PhotosSheetButton(title: "Share…") {
            navigator.dismissSheet()
            share([asset], navigator: navigator)
        })
        navigator.presentSheet(buttons)
    }

    static func email(_ assets: [PHAsset], navigator: PhotosNavigator) {
        guard MFMailComposeViewController.canSendMail() else {
            PhotosAlert.show(title: "No Mail Accounts", message: "Please set up a Mail account in order to send email.")
            return
        }
        guard let asset = assets.first else { return }
        attachment(for: asset) { attachment in
            guard let attachment else {
                PhotosAlert.show(title: "Cannot Send", message: "The item could not be prepared.")
                return
            }
            navigator.systemSheet = .mail(attachment)
        }
    }

    static func message(_ assets: [PHAsset], navigator: PhotosNavigator) {
        guard MFMessageComposeViewController.canSendText(), MFMessageComposeViewController.canSendAttachments() else {
            PhotosAlert.show(title: "Cannot Send Message", message: "Messages is not available on this device.")
            return
        }
        guard let asset = assets.first else { return }
        attachment(for: asset) { attachment in
            guard let attachment else {
                PhotosAlert.show(title: "Cannot Send", message: "The item could not be prepared.")
                return
            }
            navigator.systemSheet = .message(attachment)
        }
    }

    static func share(_ assets: [PHAsset], navigator: PhotosNavigator) {
        shareItems(for: assets) { items in
            guard !items.isEmpty else { return }
            navigator.systemSheet = .share(items)
        }
    }

    /// Trash: the red iOS 6 "Delete Photo" sheet, then the library deletion.
    static func confirmDelete(_ assets: [PHAsset], navigator: PhotosNavigator, completion: (() -> Void)? = nil) {
        guard !assets.isEmpty else { return }
        let title: String
        if assets.count == 1 {
            title = assets[0].mediaType == .video ? "Delete Video" : "Delete Photo"
        } else {
            title = "Delete \(assets.count) Items"
        }
        navigator.presentSheet([
            PhotosSheetButton(title: title, destructive: true) {
                navigator.dismissSheet()
                PhotosLibrary.shared.delete(assets) { success in
                    if success { completion?() }
                }
            }
        ])
    }
}

// MARK: - System sheets

struct PhotosShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

struct PhotosMailComposer: UIViewControllerRepresentable {
    let attachment: PhotosAttachment
    @Environment(\.dismiss) private var dismiss

    func makeCoordinator() -> Coordinator { Coordinator(dismiss: dismiss) }

    func makeUIViewController(context: Context) -> MFMailComposeViewController {
        let controller = MFMailComposeViewController()
        controller.mailComposeDelegate = context.coordinator
        controller.addAttachmentData(attachment.data, mimeType: attachment.mimeType, fileName: attachment.fileName)
        return controller
    }

    func updateUIViewController(_ uiViewController: MFMailComposeViewController, context: Context) {}

    final class Coordinator: NSObject, MFMailComposeViewControllerDelegate {
        let dismiss: DismissAction
        init(dismiss: DismissAction) { self.dismiss = dismiss }

        func mailComposeController(_ controller: MFMailComposeViewController, didFinishWith result: MFMailComposeResult, error: Error?) {
            dismiss()
        }
    }
}

struct PhotosMessageComposer: UIViewControllerRepresentable {
    let attachment: PhotosAttachment
    @Environment(\.dismiss) private var dismiss

    func makeCoordinator() -> Coordinator { Coordinator(dismiss: dismiss) }

    func makeUIViewController(context: Context) -> MFMessageComposeViewController {
        let controller = MFMessageComposeViewController()
        controller.messageComposeDelegate = context.coordinator
        controller.addAttachmentData(attachment.data, typeIdentifier: attachment.typeIdentifier, filename: attachment.fileName)
        return controller
    }

    func updateUIViewController(_ uiViewController: MFMessageComposeViewController, context: Context) {}

    final class Coordinator: NSObject, MFMessageComposeViewControllerDelegate {
        let dismiss: DismissAction
        init(dismiss: DismissAction) { self.dismiss = dismiss }

        func messageComposeViewController(_ controller: MFMessageComposeViewController, didFinishWith result: MessageComposeResult) {
            dismiss()
        }
    }
}
