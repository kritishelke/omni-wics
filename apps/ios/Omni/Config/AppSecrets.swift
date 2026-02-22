import Foundation

enum AppSecrets {
    static let shared = load()

    struct Values {
        let supabaseURL: String
        let supabaseAnonKey: String
        let apiBaseURL: String
        let oauthCallbackScheme: String
        let appGroupId: String
    }

    private static func load() -> Values {
        guard
            let path = Bundle.main.path(forResource: "Secrets", ofType: "plist"),
            let dict = NSDictionary(contentsOfFile: path) as? [String: Any],
            let supabaseURL = dict["SUPABASE_URL"] as? String,
            let supabaseAnonKey = dict["SUPABASE_ANON_KEY"] as? String,
            let apiBaseURL = dict["API_BASE_URL"] as? String,
            let oauthScheme = dict["IOS_OAUTH_CALLBACK_SCHEME"] as? String
        else {
            return Values(
                supabaseURL: "",
                supabaseAnonKey: "",
                apiBaseURL: "http://localhost:3001",
                oauthCallbackScheme: "omni",
                appGroupId: "group.com.example.omni"
            )
        }

        let appGroup = dict["APP_GROUP_ID"] as? String ?? "group.com.example.omni"

        return Values(
            supabaseURL: supabaseURL,
            supabaseAnonKey: supabaseAnonKey,
            apiBaseURL: apiBaseURL,
            oauthCallbackScheme: oauthScheme,
            appGroupId: appGroup
        )
    }
}

enum StorageKeys {
    static let session = "omni.session"
    static let onboardingComplete = "omni.onboarding.complete"
    static let selectedTab = "omni.selected.tab"
    static let screenTimeEnabled = "omni.screenTime.enabled"
    static let coachMode = "omni.coachMode"
    static let checkinCadence = "omni.checkinCadence"
}

enum OmniAPIError: LocalizedError {
    case invalidURL
    case invalidResponse
    case unauthorized
    case server(String)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid API URL. Check Secrets.plist"
        case .invalidResponse:
            return "Invalid server response"
        case .unauthorized:
            return "Unauthorized. Please sign in again."
        case .server(let message):
            return message
        }
    }
}
