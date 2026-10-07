import Foundation
import FirebaseAuth
import GoogleSignIn
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

/// Manages Google Sign-In and bridges the resulting credentials into Firebase Auth.
@Observable
final class AuthManager {
    var user: User?
    var errorMessage: String?
    var isSigningIn = false

    init() {
        // Restore any previously signed-in user
        user = Auth.auth().currentUser
    }

    var isSignedIn: Bool { user != nil }

    @MainActor
    func signInWithGoogle() async {
        isSigningIn = true
        errorMessage = nil
        defer { isSigningIn = false }

        do {
            let result: GIDSignInResult
#if canImport(UIKit)
            guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                  let rootViewController = windowScene.windows.first?.rootViewController else {
                errorMessage = "No root view controller found."
                return
            }
            result = try await GIDSignIn.sharedInstance.signIn(withPresenting: rootViewController)
#elseif canImport(AppKit)
            guard let window = NSApplication.shared.windows.first else {
                errorMessage = "No window found."
                return
            }
            result = try await GIDSignIn.sharedInstance.signIn(withPresenting: window)
#endif

            guard let idToken = result.user.idToken?.tokenString else {
                errorMessage = "Missing Google ID token."
                return
            }

            let credential = GoogleAuthProvider.credential(
                withIDToken: idToken,
                accessToken: result.user.accessToken.tokenString
            )

            let authResult = try await Auth.auth().signIn(with: credential)
            user = authResult.user
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func signOut() {
        try? Auth.auth().signOut()
        GIDSignIn.sharedInstance.signOut()
        user = nil
    }
}
