//
//  AuthService.swift
//  Jeby
//
//  The app's Firebase auth session. Views read `user` to decide whether to show
//  the Get Started card, and JebyClient will read `idToken()` for the
//  /users endpoints on the backend, which expect `Authorization: Bearer <token>`.
//

import AuthenticationServices
import CryptoKit
import FirebaseAuth
import Foundation
import Observation

/// A snapshot of the signed-in user. Firebase's own `User` is a live reference
/// type, so we copy the fields we render and leave the object to the SDK.
struct AuthUser: Equatable, Identifiable, Sendable {
    let id: String
    let displayName: String?
    let email: String?
    let photoURL: URL?

    /// Up to two initials for the avatar circle. Empty when Apple's private
    /// relay gave us neither a name nor a usable email, in which case the view
    /// falls back to a person glyph.
    var initials: String {
        let source = displayName?.trimmingCharacters(in: .whitespaces) ?? ""
        if !source.isEmpty {
            let parts = source.split(separator: " ").prefix(2)
            return parts.compactMap(\.first).map(String.init).joined().uppercased()
        }
        if let first = email?.trimmingCharacters(in: .whitespaces).first {
            return String(first).uppercased()
        }
        return ""
    }
}

enum AuthError: LocalizedError {
    case missingAppleToken
    case notSignedIn

    var errorDescription: String? {
        switch self {
        case .missingAppleToken:
            return "Apple didn't return a sign-in token. Try again."
        case .notSignedIn:
            return "You need to be signed in to do that."
        }
    }
}

@MainActor
@Observable
final class AuthService {

    /// The signed-in user, or nil when signed out. Views watch this.
    private(set) var user: AuthUser?

    /// True while a sign-in is in flight, so the card can disable its buttons.
    private(set) var isWorking = false

    /// Last sign-in failure, shown inline on the Get Started card. Cleared when
    /// a new attempt starts.
    private(set) var errorMessage: String?

    /// Set when the last sign-in created a brand-new account, which is what
    /// launches onboarding. Views clear it once they've handled it, so a later
    /// sign-in on the same launch doesn't re-trigger the flow.
    private(set) var needsOnboarding = false

    /// A non-error message for the sign-in form (currently just the
    /// password-reset confirmation).
    private(set) var noticeMessage: String?

    var isSignedIn: Bool { user != nil }

    /// Marks onboarding as handled, so it doesn't reopen on the next state change.
    func onboardingHandled() {
        needsOnboarding = false
    }

    /// Clears whatever the form is showing — call when switching between the
    /// sign-in and sign-up modes so a stale error doesn't linger.
    func clearMessages() {
        errorMessage = nil
        noticeMessage = nil
    }

    /// Raw nonce for the Apple request in flight. Apple signs the SHA-256 of it
    /// and Firebase checks the raw value against that hash, which is what stops
    /// a stolen Apple token from being replayed.
    private var currentNonce: String?

    /// Written once in init and read once in deinit, which is nonisolated — so
    /// the actor check has to be waived here. There's no window where the two
    /// can race.
    private nonisolated(unsafe) var listener: AuthStateDidChangeListenerHandle?

    /// Begins tracking the Firebase session. Idempotent, and must not be called
    /// before `FirebaseApp.configure()`.
    ///
    /// This deliberately isn't done in `init`: SwiftUI builds the `App` struct's
    /// stored properties while the process launches, which is *before* UIKit
    /// calls the app delegate's `didFinishLaunchingWithOptions` — so touching
    /// `Auth.auth()` from an initializer traps on an unconfigured Firebase.
    /// ContentView calls this from `.task`, by which point configuration is done.
    func start() {
        guard listener == nil else { return }

        // Fires immediately with the persisted session, so a returning user is
        // signed back in a beat after launch without another Apple prompt.
        listener = Auth.auth().addStateDidChangeListener { _, user in
            let snapshot = user.map(AuthUser.init(firebaseUser:))
            Task { @MainActor [weak self] in
                self?.user = snapshot
            }
        }
    }

    deinit {
        if let listener {
            Auth.auth().removeStateDidChangeListener(listener)
        }
    }

    // MARK: - Sign in with Apple

    /// Configures the Apple request. Called from `SignInWithAppleButton`'s
    /// onRequest, which is why it hands back a nonce rather than taking one.
    func prepareAppleRequest(_ request: ASAuthorizationAppleIDRequest) {
        errorMessage = nil
        let nonce = Self.randomNonce()
        currentNonce = nonce
        request.requestedScopes = [.fullName, .email]
        request.nonce = Self.sha256(nonce)
    }

    /// Exchanges Apple's credential for a Firebase session.
    func completeAppleSignIn(_ result: Result<ASAuthorization, Error>) async {
        switch result {
        case .failure(let error):
            // Backing out of the Apple sheet isn't an error worth showing.
            if (error as? ASAuthorizationError)?.code == .canceled {
                currentNonce = nil
                return
            }
            errorMessage = error.localizedDescription
            currentNonce = nil

        case .success(let authorization):
            guard
                let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
                let tokenData = credential.identityToken,
                let idToken = String(data: tokenData, encoding: .utf8),
                let nonce = currentNonce
            else {
                errorMessage = AuthError.missingAppleToken.errorDescription
                currentNonce = nil
                return
            }

            // Apple sends the full name only on the very first authorization, so
            // pass it through here or it's gone for good.
            let firebaseCredential = OAuthProvider.appleCredential(
                withIDToken: idToken,
                rawNonce: nonce,
                fullName: credential.fullName
            )

            await perform { try await Auth.auth().signIn(with: firebaseCredential) }
            currentNonce = nil
        }
    }

    // MARK: - Email and password

    /// Creates an account. New by definition, so this always leads to onboarding.
    func signUp(email: String, password: String) async {
        await perform {
            try await Auth.auth().createUser(
                withEmail: email.trimmingCharacters(in: .whitespaces),
                password: password
            )
        }
    }

    /// Signs in to an existing account.
    func signIn(email: String, password: String) async {
        await perform {
            try await Auth.auth().signIn(
                withEmail: email.trimmingCharacters(in: .whitespaces),
                password: password
            )
        }
    }

    /// Sends a password reset email. Reports success through `noticeMessage` so
    /// the form can confirm without navigating away.
    func sendPasswordReset(email: String) async {
        isWorking = true
        errorMessage = nil
        noticeMessage = nil
        defer { isWorking = false }

        do {
            try await Auth.auth().sendPasswordReset(withEmail: email.trimmingCharacters(in: .whitespaces))
            noticeMessage = "Check your inbox for a reset link."
        } catch {
            errorMessage = Self.message(for: error)
        }
    }

    // MARK: - Session

    func signOut() {
        do {
            try Auth.auth().signOut()
            errorMessage = nil
            noticeMessage = nil
            needsOnboarding = false
        } catch {
            errorMessage = Self.message(for: error)
        }
    }

    /// Mirrors a profile edit onto the Firebase user record so the avatar button
    /// and any other reader of `user` update immediately, rather than waiting for
    /// the next profile fetch. Best-effort: jeby-go is the source of truth, so a
    /// failure here is logged and swallowed rather than failing the step.
    func refreshProfile(displayName: String?, photoURL: String?) async {
        guard let firebaseUser = Auth.auth().currentUser else { return }

        let change = firebaseUser.createProfileChangeRequest()
        if let displayName { change.displayName = displayName }
        if let photoURL { change.photoURL = URL(string: photoURL) }

        do {
            try await change.commitChanges()
            user = AuthUser(firebaseUser: firebaseUser)
        } catch {
            print("auth: could not mirror profile onto Firebase: \(error.localizedDescription)")
        }
    }

    /// A fresh Firebase ID token for the backend's `Authorization: Bearer` header.
    /// Firebase refreshes it automatically when it's close to expiring, so call
    /// this per request rather than holding onto the result.
    func idToken() async throws -> String {
        guard let user = Auth.auth().currentUser else { throw AuthError.notSignedIn }
        return try await user.getIDToken()
    }

    // MARK: - Plumbing

    /// Runs a sign-in call with the shared working/error handling. The state
    /// listener publishes the resulting user, so there's no user to assign here —
    /// what this does own is noticing a brand-new account, which is what starts
    /// onboarding.
    private func perform(_ work: () async throws -> AuthDataResult) async {
        isWorking = true
        errorMessage = nil
        noticeMessage = nil
        defer { isWorking = false }

        do {
            let result = try await work()
            if result.additionalUserInfo?.isNewUser == true {
                needsOnboarding = true
            }
        } catch {
            errorMessage = Self.message(for: error)
        }
    }

    /// Firebase's own messages are serviceable but leak jargon ("The password is
    /// invalid or the user does not have a password"), so the handful people
    /// actually hit get rewritten.
    private static func message(for error: Error) -> String {
        guard let code = AuthErrorCode(rawValue: (error as NSError).code) else {
            return error.localizedDescription
        }

        switch code {
        case .emailAlreadyInUse:
            return "That email already has an account. Try signing in instead."
        case .invalidEmail:
            return "That doesn't look like a valid email address."
        case .weakPassword:
            return "Pick a password at least 6 characters long."
        case .wrongPassword, .invalidCredential:
            return "That email and password don't match."
        case .userNotFound:
            return "No account for that email yet. Create one below."
        case .networkError:
            return "Couldn't reach Firebase. Check your connection."
        case .tooManyRequests:
            return "Too many attempts. Wait a minute and try again."
        default:
            return error.localizedDescription
        }
    }

    /// A cryptographically random nonce, in the URL-safe alphabet Apple accepts.
    private static func randomNonce(length: Int = 32) -> String {
        let charset = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        var bytes = [UInt8](repeating: 0, count: length)
        let status = SecRandomCopyBytes(kSecRandomDefault, length, &bytes)
        guard status == errSecSuccess else {
            // SecRandomCopyBytes only fails if the system RNG is unavailable,
            // at which point nothing about this session is trustworthy.
            fatalError("Unable to generate a secure nonce: OSStatus \(status)")
        }
        return String(bytes.map { charset[Int($0) % charset.count] })
    }

    private static func sha256(_ input: String) -> String {
        SHA256.hash(data: Data(input.utf8))
            .map { String(format: "%02x", $0) }
            .joined()
    }
}

private extension AuthUser {
    init(firebaseUser: User) {
        self.init(
            id: firebaseUser.uid,
            displayName: firebaseUser.displayName,
            email: firebaseUser.email,
            photoURL: firebaseUser.photoURL
        )
    }
}
