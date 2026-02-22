import Foundation
import AuthenticationServices
import DeviceActivity

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

extension DeviceActivityEvent.Name {
    static let driftThreshold = Self("driftThreshold")
}
