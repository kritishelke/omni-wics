import Foundation
import AuthenticationServices
import SwiftUI

extension JSONDecoder {
    static var omni: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return decoder
    }
}

enum OmniDateParser {
    private static let fractionalISO8601: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    private static let internetDateTimeISO8601: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()

    static func parse(_ value: String) -> Date? {
        fractionalISO8601.date(from: value) ?? internetDateTimeISO8601.date(from: value)
    }

    static func dayString(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }
}

extension Error {
    var isOmniCancellation: Bool {
        if self is CancellationError {
            return true
        }

        let nsError = self as NSError
        if nsError.domain == NSURLErrorDomain && nsError.code == NSURLErrorCancelled {
            return true
        }

        if nsError.domain == ASWebAuthenticationSessionError.errorDomain,
           nsError.code == ASWebAuthenticationSessionError.canceledLogin.rawValue
        {
            return true
        }

        let message = nsError.localizedDescription.lowercased()
        return message == "cancelled" || message == "canceled"
    }
}

extension Color {
    static let omniBackground = Color(red: 0.01, green: 0.06, blue: 0.07)
    static let omniCard = Color(red: 0.05, green: 0.15, blue: 0.14)
    static let omniAccent = Color(red: 0.34, green: 0.94, blue: 0.76)
    static let omniAccentDeep = Color(red: 0.12, green: 0.53, blue: 0.43)
    static let omniMuted = Color(red: 0.69, green: 0.78, blue: 0.75)
    static let omniGlow = Color(red: 0.88, green: 1.00, blue: 0.96)
    static let omniSoftBlock = Color(red: 0.12, green: 0.34, blue: 0.31)
    static let omniHardBlock = Color(red: 0.13, green: 0.62, blue: 0.50)
}

extension Font {
    static func omniScript(size: CGFloat) -> Font {
        Font.custom("Snell Roundhand", size: size)
    }
}

struct OmniNebulaBackground: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color.omniBackground, Color.omniCard, Color.black],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            RadialGradient(
                colors: [Color.omniAccent.opacity(0.30), .clear],
                center: .topTrailing,
                startRadius: 10,
                endRadius: 320
            )

            RadialGradient(
                colors: [Color.omniGlow.opacity(0.22), .clear],
                center: .center,
                startRadius: 5,
                endRadius: 190
            )

            Circle()
                .fill(Color.omniAccent.opacity(0.12))
                .blur(radius: 70)
                .scaleEffect(1.4)
                .offset(x: -120, y: 260)
        }
        .ignoresSafeArea()
    }
}

private struct OmniGlassCardModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [Color.white.opacity(0.11), Color.black.opacity(0.35)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(Color.omniAccent.opacity(0.25), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.35), radius: 14, x: 0, y: 10)
    }
}

extension View {
    func omniGlassCard() -> some View {
        modifier(OmniGlassCardModifier())
    }
}
