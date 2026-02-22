import Foundation
import AuthenticationServices
import UIKit

final class WebAuthSessionRunner: NSObject, ASWebAuthenticationPresentationContextProviding {
    private var continuation: CheckedContinuation<URL, Error>?
    private var activeSession: ASWebAuthenticationSession?

    @MainActor
    func run(url: URL, callbackScheme: String) async throws -> URL {
        try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                self.continuation = continuation

                let session = ASWebAuthenticationSession(
                    url: url,
                    callbackURLScheme: callbackScheme
                ) { [weak self] callbackURL, error in
                    guard let self else { return }
                    self.activeSession = nil

                    guard let continuation = self.continuation else { return }
                    self.continuation = nil

                    if let error {
                        continuation.resume(throwing: error)
                        return
                    }

                    guard let callbackURL else {
                        continuation.resume(throwing: OmniAPIError.invalidResponse)
                        return
                    }

                    continuation.resume(returning: callbackURL)
                }

                session.presentationContextProvider = self
                session.prefersEphemeralWebBrowserSession = true
                self.activeSession = session

                guard session.start() else {
                    self.activeSession = nil
                    self.continuation = nil
                    continuation.resume(
                        throwing: OmniAPIError.server("Unable to start Google OAuth session.")
                    )
                    return
                }
            }
        } onCancel: { [weak self] in
            Task { @MainActor in
                guard let self, let continuation = self.continuation else { return }
                self.activeSession?.cancel()
                self.activeSession = nil
                self.continuation = nil
                continuation.resume(throwing: CancellationError())
            }
        }
    }

    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first?.windows.first { $0.isKeyWindow } ?? ASPresentationAnchor()
    }
}

final class SupabaseOAuthService {
    private let secrets = AppSecrets.shared

    @MainActor
    func signInWithEmail(email: String, password: String) async throws -> OmniSession {
        let normalizedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let normalizedPassword = password.trimmingCharacters(in: .whitespacesAndNewlines)

        guard normalizedEmail.isEmpty == false, normalizedPassword.isEmpty == false else {
            throw OmniAPIError.server("Email and password are required.")
        }

        guard let url = URL(string: "\(secrets.supabaseURL)/auth/v1/token?grant_type=password") else {
            throw OmniAPIError.invalidURL
        }

        let session = try await performAuthRequest(
            url: url,
            payload: [
                "email": normalizedEmail,
                "password": normalizedPassword
            ]
        )
        persist(session)
        return session
    }

    @MainActor
    func signUpWithEmail(email: String, password: String) async throws -> OmniSession {
        let normalizedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let normalizedPassword = password.trimmingCharacters(in: .whitespacesAndNewlines)

        guard normalizedEmail.isEmpty == false, normalizedPassword.isEmpty == false else {
            throw OmniAPIError.server("Email and password are required.")
        }

        guard let url = URL(string: "\(secrets.supabaseURL)/auth/v1/signup") else {
            throw OmniAPIError.invalidURL
        }

        let signupPayload: [String: String] = [
            "email": normalizedEmail,
            "password": normalizedPassword
        ]

        do {
            let session = try await performAuthRequest(url: url, payload: signupPayload)
            persist(session)
            return session
        } catch {
            // When account already exists, fallback to normal sign-in for smoother UX.
            if let message = (error as? OmniAPIError)?.errorDescription?.lowercased(),
               message.contains("already") {
                return try await signInWithEmail(email: normalizedEmail, password: normalizedPassword)
            }
            throw error
        }
    }

    func restoreSession() -> OmniSession? {
        guard let data = UserDefaults.standard.data(forKey: StorageKeys.session) else { return nil }
        return try? JSONDecoder().decode(OmniSession.self, from: data)
    }

    func clearSession() {
        UserDefaults.standard.removeObject(forKey: StorageKeys.session)
    }

    private func persist(_ session: OmniSession) {
        if let data = try? JSONEncoder().encode(session) {
            UserDefaults.standard.set(data, forKey: StorageKeys.session)
        }
    }

    private func performAuthRequest(
        url: URL,
        payload: [String: String]
    ) async throws -> OmniSession {
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(secrets.supabaseAnonKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(secrets.supabaseAnonKey)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw OmniAPIError.invalidResponse
        }

        guard (200..<300).contains(httpResponse.statusCode) else {
            throw OmniAPIError.server(Self.extractSupabaseError(from: data))
        }

        let decoded = try JSONDecoder.omni.decode(SupabaseSessionResponse.self, from: data)
        guard let accessToken = decoded.accessToken, accessToken.isEmpty == false else {
            throw OmniAPIError.server(
                "Account created. Check your email for verification, then sign in."
            )
        }

        return OmniSession(
            accessToken: accessToken,
            refreshToken: decoded.refreshToken
        )
    }

    private static func extractSupabaseError(from data: Data) -> String {
        guard data.isEmpty == false else {
            return "Supabase auth request failed."
        }

        if let decoded = try? JSONDecoder.omni.decode(SupabaseErrorResponse.self, from: data) {
            if let msg = decoded.msg, msg.isEmpty == false { return msg }
            if let description = decoded.errorDescription, description.isEmpty == false { return description }
            if let message = decoded.message, message.isEmpty == false { return message }
            if let error = decoded.error, error.isEmpty == false { return error }
        }

        return String(data: data, encoding: .utf8) ?? "Supabase auth request failed."
    }
}

private struct SupabaseSessionResponse: Decodable {
    let accessToken: String?
    let refreshToken: String?
}

private struct SupabaseErrorResponse: Decodable {
    let error: String?
    let errorDescription: String?
    let msg: String?
    let message: String?
}
