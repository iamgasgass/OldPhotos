import SwiftUI
import UIKit
import Combine

@main
final class OldPhotosAppDelegate: UIResponder, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        UIDevice.current.beginGeneratingDeviceOrientationNotifications()
        _ = PhotosSettings.shared
        return true
    }

    func application(
        _ application: UIApplication,
        configurationForConnecting connectingSceneSession: UISceneSession,
        options: UIScene.ConnectionOptions
    ) -> UISceneConfiguration {
        let configuration = UISceneConfiguration(name: "Default Configuration", sessionRole: connectingSceneSession.role)
        configuration.delegateClass = OldPhotosSceneDelegate.self
        return configuration
    }

    func application(_ application: UIApplication, supportedInterfaceOrientationsFor window: UIWindow?) -> UIInterfaceOrientationMask {
        .portrait
    }
}

final class OldPhotosSceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?

    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        guard let windowScene = scene as? UIWindowScene else { return }
        let window = UIWindow(windowScene: windowScene)
        window.rootViewController = OldPhotosHostingController(root: OldPhotosRootView())
        window.backgroundColor = .black
        self.window = window
        window.makeKeyAndVisible()
        PhotosSettings.shared.apply()
    }

    func sceneDidBecomeActive(_ scene: UIScene) {
        PhotosSettings.shared.apply()
    }
}

/// Hosts the SwiftUI app: light status bar over the black chrome, hidden
/// together with the bars in the full-screen viewer.
final class OldPhotosHostingController: UIHostingController<OldPhotosRootView> {
    private var cancellables = Set<AnyCancellable>()

    init(root: OldPhotosRootView) {
        super.init(rootView: root)
        PhotosStatusBar.shared.$hidden
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                UIView.animate(withDuration: 0.25) {
                    self?.setNeedsStatusBarAppearanceUpdate()
                }
            }
            .store(in: &cancellables)
    }

    @MainActor required dynamic init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var preferredStatusBarStyle: UIStatusBarStyle {
        .lightContent
    }

    override var prefersStatusBarHidden: Bool {
        PhotosStatusBar.shared.hidden
    }

    override var preferredStatusBarUpdateAnimation: UIStatusBarAnimation {
        .fade
    }

    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        .portrait
    }
}
