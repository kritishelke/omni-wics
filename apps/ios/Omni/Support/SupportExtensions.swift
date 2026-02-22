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
    static let omniBackground = Color(red: 0.02, green: 0.05, blue: 0.08)
    static let omniCard = Color(red: 0.03, green: 0.08, blue: 0.10)
    static let omniAccent = Color(red: 0.11, green: 0.83, blue: 0.74)
    static let omniMuted = Color(red: 0.65, green: 0.71, blue: 0.74)
}
