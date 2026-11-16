@preconcurrency import FirebaseAuth
import Foundation
@preconcurrency import GoogleSignIn
import Observation
import UIKit

@MainActor
@Observable
public final class AuthService {
    public private(set) var currentUser: User?
    public private(set) var isSigningIn: Bool = false
    public private(set) var errorMessage: String?

    private var authStateHandle: AuthStateDidChangeListenerHandle?

    public init() {
        self.currentUser = Auth.auth().currentUser
        self.authStateHandle = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            Task { @MainActor [weak self] in
                self?.currentUser = user
            }
        }
    }

    public func attemptAutoSignIn() async {
        if Auth.auth().currentUser != nil {
            self.currentUser = Auth.auth().currentUser
            return
        }
        guard GIDSignIn.sharedInstance.hasPreviousSignIn() else { return }
        isSigningIn = true
        defer { isSigningIn = false }
        do {
            let gidUser = try await GIDSignIn.sharedInstance.restorePreviousSignIn()
            try await signInToFirebase(with: gidUser)
        } catch {
            // Silent auto sign-in failure is non-fatal; user can tap Sign in with Google
        }
    }

    public func signInWithGoogle() async {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootVC = windowScene.windows.first(where: { $0.isKeyWindow })?.rootViewController else {
            errorMessage = "Unable to locate root view controller."
            return
        }

        isSigningIn = true
        errorMessage = nil
        defer { isSigningIn = false }

        do {
            let result = try await GIDSignIn.sharedInstance.signIn(withPresenting: rootVC)
            try await signInToFirebase(with: result.user)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    public func signOut() {
        do {
            try Auth.auth().signOut()
            GIDSignIn.sharedInstance.signOut()
            currentUser = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func signInToFirebase(with gidUser: GIDGoogleUser) async throws {
        guard let idToken = gidUser.idToken?.tokenString else {
            throw NSError(domain: "AuthService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Missing Google ID token"])
        }
        let credential = GoogleAuthProvider.credential(
            withIDToken: idToken,
            accessToken: gidUser.accessToken.tokenString
        )
        let authResult = try await Auth.auth().signIn(with: credential)
        self.currentUser = authResult.user
    }
}
