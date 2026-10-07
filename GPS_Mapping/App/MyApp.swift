import SwiftUI
import FirebaseCore
import GoogleSignIn

@main struct MyApp: App {
    @State private var authManager = AuthManager()

    init() {
        // Configure Firebase from our renamed plist (defaults expect GoogleService-Info.plist).
        if let path = Bundle.main.path(forResource: "GPS-Tracker-Pico2W", ofType: "plist"),
           let options = FirebaseOptions(contentsOfFile: path) {
            FirebaseApp.configure(options: options)
        } else {
            FirebaseApp.configure()
        }

        // Tell Google Sign-In to use the client ID from the Firebase config.
        if let clientID = FirebaseApp.app()?.options.clientID {
            GIDSignIn.sharedInstance.configuration = GIDConfiguration(clientID: clientID)
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(authManager)
                .onOpenURL { url in
                    // Forward the Google Sign-In redirect back to the SDK.
                    GIDSignIn.sharedInstance.handle(url)
                }
        }
    }
}
