import FirebaseAppCheck
import FirebaseCore
import GoogleSignIn
import SwiftUI

final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        // Register App Check provider BEFORE FirebaseApp.configure() (Section 9.1)
        #if DEBUG
        AppCheck.setAppCheckProviderFactory(AppCheckDebugProviderFactory())
        #else
        AppCheck.setAppCheckProviderFactory(AppAttestProviderFactory())
        #endif

        FirebaseApp.configure()
        return true
    }

    func application(
        _ app: UIApplication,
        open url: URL,
        options: [UIApplication.OpenURLOptionsKey: Any] = [:]
    ) -> Bool {
        GIDSignIn.sharedInstance.handle(url)
    }
}

#if !DEBUG
final class AppAttestProviderFactory: NSObject, AppCheckProviderFactory {
    func createProvider(with app: FirebaseApp) -> AppCheckProvider? {
        AppAttestProvider(app: app)
    }
}
#endif

@main
struct AITranslatorApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    @State private var prefsManager = LocalPreferencesManager()
    @State private var authService = AuthService()
    @State private var userRepo = UserSettingsRepository()
    @State private var remoteConfig = RemoteInterpreterConfig()

    var body: some Scene {
        WindowGroup {
            RootView(
                prefsManager: prefsManager,
                authService: authService,
                userRepo: userRepo,
                remoteConfig: remoteConfig
            )
            .preferredColorScheme(.dark)
        }
    }
}
