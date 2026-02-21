import SwiftUI
import Foundation
import AuthenticationServices
import UserNotifications
import FamilyControls
import DeviceActivity

#if canImport(Supabase)
import Supabase
#endif

struct OmniSession: Codable {
    let accessToken: String
    let refreshToken: String?
}

struct UserProfileDTO: Codable {
    let id: String
    let coachMode: String
    let checkinCadenceMinutes: Int
    let sleepTime: String?
    let wakeTime: String?

    enum CodingKeys: String, CodingKey {
        case id
        case coachMode
        case checkinCadenceMinutes
        case sleepTime
        case wakeTime
    }
}

struct PlanBlockDTO: Codable, Identifiable, Hashable {
    let id: String?
    let planId: String?
    let userId: String?
    let startAt: String
    let endAt: String
    let type: String
    let googleTaskId: String?
    let label: String
    let rationale: String
    let priorityScore: Double

    var startDate: Date? { ISO8601DateFormatter.omni.date(from: startAt) }
    var endDate: Date? { ISO8601DateFormatter.omni.date(from: endAt) }

    var effectiveId: String {
        id ?? "\(startAt)-\(label)"
    }
}

struct PlanDTO: Codable {
    let id: String?
    let userId: String?
    let planDate: String
    let topOutcomes: [String]
    let shutdownSuggestion: String?
    let riskFlags: [String]
    let blocks: [PlanBlockDTO]
}

struct TaskDTO: Codable, Identifiable {
    let id: String
    let taskListId: String
    let title: String
    let notes: String?
    let dueAt: String?
    let status: String
    let parentTaskId: String?
    let updatedAt: String
    let source: String
}

struct NudgeDTO: Codable {
    let id: String
    let triggerType: String
    let recommendedAction: String
    let alternatives: [String]
    let acceptedAction: String?
    let relatedBlockId: String?
    let rationale: String
    let ts: String?
}

struct BreakdownDTO: Codable {
    struct Subtask: Codable, Hashable {
        let title: String
        let estimatedMinutes: Int
        let order: Int
    }

    let subtasks: [Subtask]
}

struct DayCloseResponseDTO: Codable {
    let summary: String
    let tomorrowTop3: [String]
    let tomorrowAdjustments: [String]
}

struct HealthResponse: Codable {
    let ok: Bool
}

struct PlanGenerationRequest: Codable {
    let date: String
    let energy: String
}

struct PatchProfileInput: Codable {
    let coachMode: String?
    let checkinCadenceMinutes: Int?
    let sleepTime: String?
    let wakeTime: String?
}

struct DriftEvent: Codable, Identifiable, Hashable {
    let id: String
    let ts: String
    let minutes: Int?
    let blockId: String?
    let apps: [String]
}

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

final class APIClient {
    private let baseURL: URL

    init(baseURL: String) {
        self.baseURL = URL(string: baseURL) ?? URL(string: "http://localhost:3001")!
    }

    func health() async throws -> HealthResponse {
        try await request(path: "/v1/health", method: "GET", accessToken: nil, body: Optional<String>.none)
    }

    func profile(accessToken: String) async throws -> UserProfileDTO {
        try await request(path: "/v1/profile", method: "GET", accessToken: accessToken, body: Optional<String>.none)
    }

    func patchProfile(accessToken: String, body: PatchProfileInput) async throws -> UserProfileDTO {
        try await request(path: "/v1/profile", method: "PATCH", accessToken: accessToken, body: body)
    }

    func disconnectGoogle(accessToken: String) async throws {
        _ = try await request(path: "/v1/profile/google-connection", method: "DELETE", accessToken: accessToken, body: Optional<String>.none) as EmptyDTO
    }

    func startGoogleOAuth(accessToken: String, callbackScheme: String) async throws -> URL {
        struct Input: Codable { let callbackScheme: String }
        struct Output: Codable { let url: String }
        let output: Output = try await request(
            path: "/v1/google/oauth/start",
            method: "POST",
            accessToken: accessToken,
            body: Input(callbackScheme: callbackScheme)
        )
        guard let url = URL(string: output.url) else {
            throw OmniAPIError.invalidResponse
        }
        return url
    }

    func calendarEvents(accessToken: String, date: String) async throws -> [[String: String]] {
        try await request(path: "/v1/google/calendar/events?date=\(date)", method: "GET", accessToken: accessToken, body: Optional<String>.none)
    }

    func fetchTasks(accessToken: String) async throws -> [TaskDTO] {
        try await request(path: "/v1/google/tasks", method: "GET", accessToken: accessToken, body: Optional<String>.none)
    }

    func createTask(accessToken: String, title: String) async throws -> TaskDTO {
        struct Input: Codable { let title: String }
        return try await request(path: "/v1/google/tasks/create", method: "POST", accessToken: accessToken, body: Input(title: title))
    }

    func completeTask(accessToken: String, taskId: String) async throws -> TaskDTO {
        struct Response: Codable { let ok: Bool; let task: TaskDTO }
        let response: Response = try await request(
            path: "/v1/google/tasks/\(taskId)/complete",
            method: "POST",
            accessToken: accessToken,
            body: Optional<String>.none
        )
        return response.task
    }

    func generatePlan(accessToken: String, date: String, energy: String) async throws -> PlanDTO {
        try await request(path: "/v1/ai/plan", method: "POST", accessToken: accessToken, body: PlanGenerationRequest(date: date, energy: energy))
    }

    func todayPlan(accessToken: String) async throws -> PlanDTO? {
        try await request(path: "/v1/plans/today", method: "GET", accessToken: accessToken, body: Optional<String>.none)
    }

    func plan(accessToken: String, date: String) async throws -> PlanDTO? {
        try await request(path: "/v1/plans/\(date)", method: "GET", accessToken: accessToken, body: Optional<String>.none)
    }

    func sendCheckin(accessToken: String, planBlockId: String, progress: Double, focus: Double, energy: String?) async throws -> [String: AnyDecodable] {
        struct Input: Codable {
            let planBlockId: String
            let progress: Double
            let focus: Double
            let energy: String?
        }

        return try await request(
            path: "/v1/signals/checkin",
            method: "POST",
            accessToken: accessToken,
            body: Input(planBlockId: planBlockId, progress: progress, focus: focus, energy: energy)
        )
    }

    func sendDrift(accessToken: String, planBlockId: String?, minutes: Int?, apps: [String]) async throws -> [String: AnyDecodable] {
        struct Input: Codable {
            let planBlockId: String?
            let minutes: Int?
            let apps: [String]
        }

        return try await request(
            path: "/v1/signals/drift",
            method: "POST",
            accessToken: accessToken,
            body: Input(planBlockId: planBlockId, minutes: minutes, apps: apps)
        )
    }

    func requestNudge(accessToken: String, planBlockId: String, triggerType: String, payload: [String: String]) async throws -> NudgeDTO {
        struct Input: Codable {
            let planBlockId: String
            let triggerType: String
            let signalPayload: [String: String]
        }

        return try await request(
            path: "/v1/ai/nudge",
            method: "POST",
            accessToken: accessToken,
            body: Input(planBlockId: planBlockId, triggerType: triggerType, signalPayload: payload)
        )
    }

    func requestBreakdown(accessToken: String, taskId: String?, title: String, dueAt: String?) async throws -> BreakdownDTO {
        struct Input: Codable {
            let googleTaskId: String?
            let title: String
            let dueAt: String?
        }

        return try await request(
            path: "/v1/ai/breakdown",
            method: "POST",
            accessToken: accessToken,
            body: Input(googleTaskId: taskId, title: title, dueAt: dueAt)
        )
    }

    func dayClose(accessToken: String, date: String, completedOutcomes: [String], biggestBlocker: String?, energyEnd: String?, notes: String?) async throws -> DayCloseResponseDTO {
        struct Input: Codable {
            let date: String
            let completedOutcomes: [String]
            let biggestBlocker: String?
            let energyEnd: String?
            let notes: String?
        }

        return try await request(
            path: "/v1/ai/day-close",
            method: "POST",
            accessToken: accessToken,
            body: Input(date: date, completedOutcomes: completedOutcomes, biggestBlocker: biggestBlocker, energyEnd: energyEnd, notes: notes)
        )
    }

    private func request<Response: Decodable, Body: Encodable>(
        path: String,
        method: String,
        accessToken: String?,
        body: Body?
    ) async throws -> Response {
        guard let url = URL(string: path, relativeTo: baseURL) else {
            throw OmniAPIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        if let accessToken {
            request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        }

        if let body {
            if let dictionaryBody = body as? [String: Any] {
                request.httpBody = try JSONSerialization.data(withJSONObject: dictionaryBody)
            } else {
                request.httpBody = try JSONEncoder().encode(body)
            }
        }

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw OmniAPIError.invalidResponse
        }

        guard (200..<300).contains(httpResponse.statusCode) else {
            if httpResponse.statusCode == 401 {
                throw OmniAPIError.unauthorized
            }

            let message = String(data: data, encoding: .utf8) ?? "Request failed"
            throw OmniAPIError.server(message)
        }

        if Response.self == EmptyDTO.self {
            return EmptyDTO() as! Response
        }

        if data.isEmpty {
            throw OmniAPIError.invalidResponse
        }

        return try JSONDecoder.omni.decode(Response.self, from: data)
    }
}

struct EmptyDTO: Codable {}

struct AnyDecodable: Decodable {}

final class WebAuthSessionRunner: NSObject, ASWebAuthenticationPresentationContextProviding {
    private var continuation: CheckedContinuation<URL, Error>?

    @MainActor
    func run(url: URL, callbackScheme: String) async throws -> URL {
        try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation
            let session = ASWebAuthenticationSession(
                url: url,
                callbackURLScheme: callbackScheme
            ) { callbackURL, error in
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
            _ = session.start()
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
    func signInWithApple() async throws -> OmniSession {
        let callbackURLString = "\(secrets.oauthCallbackScheme)://auth/callback"
        guard
            let callbackURL = callbackURLString.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
            let authorizeURL = URL(string: "\(secrets.supabaseURL)/auth/v1/authorize?provider=apple&redirect_to=\(callbackURL)")
        else {
            throw OmniAPIError.invalidURL
        }

        let runner = WebAuthSessionRunner()
        let callback = try await runner.run(url: authorizeURL, callbackScheme: secrets.oauthCallbackScheme)
        let session = try Self.sessionFromCallback(url: callback)
        persist(session)
        return session
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

    private static func sessionFromCallback(url: URL) throws -> OmniSession {
        let raw = url.absoluteString
        let fragment = raw.components(separatedBy: "#").dropFirst().first ?? ""
        let params = fragment
            .components(separatedBy: "&")
            .compactMap { part -> (String, String)? in
                let bits = part.components(separatedBy: "=")
                guard bits.count == 2 else { return nil }
                return (bits[0], bits[1].removingPercentEncoding ?? bits[1])
            }

        let map = Dictionary(uniqueKeysWithValues: params)
        guard let accessToken = map["access_token"] else {
            throw OmniAPIError.server("Supabase callback did not include access_token")
        }

        return OmniSession(accessToken: accessToken, refreshToken: map["refresh_token"])
    }
}

final class DriftEventStore {
    private static let key = "omni.drift.events"

    static func append(_ event: DriftEvent) {
        var existing = readAll()
        existing.append(event)
        save(existing)
    }

    static func readAll() -> [DriftEvent] {
        let defaults = UserDefaults(suiteName: AppSecrets.shared.appGroupId) ?? .standard
        guard let data = defaults.data(forKey: key) else { return [] }
        return (try? JSONDecoder().decode([DriftEvent].self, from: data)) ?? []
    }

    static func clear() {
        let defaults = UserDefaults(suiteName: AppSecrets.shared.appGroupId) ?? .standard
        defaults.removeObject(forKey: key)
    }

    private static func save(_ events: [DriftEvent]) {
        let defaults = UserDefaults(suiteName: AppSecrets.shared.appGroupId) ?? .standard
        if let data = try? JSONEncoder().encode(events) {
            defaults.set(data, forKey: key)
        }
    }
}

@MainActor
final class NotificationManager {
    func requestPermission() async {
        _ = try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge])
    }

    func scheduleForPlan(_ plan: PlanDTO, checkinCadenceMinutes: Int) {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()

        for block in plan.blocks {
            guard block.type == "task" || block.type == "sticky" else { continue }
            guard let start = block.startDate, let end = block.endDate else { continue }

            schedule(title: "Start: \(block.label)", at: start, deepLink: "omni://now")

            var next = start.addingTimeInterval(TimeInterval(checkinCadenceMinutes * 60))
            while next < end {
                schedule(title: "Check-in: \(block.label)", at: next, deepLink: "omni://now")
                next = next.addingTimeInterval(TimeInterval(checkinCadenceMinutes * 60))
            }
        }
    }

    private func schedule(title: String, at date: Date, deepLink: String) {
        guard date > Date() else { return }

        let content = UNMutableNotificationContent()
        content.title = title
        content.body = "Open Omni Now"
        content.sound = .default
        content.userInfo = ["deepLink": deepLink]

        let interval = date.timeIntervalSinceNow
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: max(1, interval), repeats: false)
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request)
    }
}

@MainActor
final class ScreenTimeManager: ObservableObject {
    @Published var selection = FamilyActivitySelection()
    @Published var authorizationStatus: AuthorizationStatus = .notDetermined
    @Published var lastError: String?

    private let activityCenter = DeviceActivityCenter()

    enum AuthorizationStatus {
        case notDetermined
        case approved
        case denied
        case unavailable
    }

    func requestAuthorization() async {
        guard ProcessInfo.processInfo.isiOSAppOnMac == false else {
            authorizationStatus = .unavailable
            return
        }

        do {
            try await AuthorizationCenter.shared.requestAuthorization(for: .individual)
            authorizationStatus = .approved
            persistSelection()
        } catch {
            authorizationStatus = .denied
            lastError = error.localizedDescription
        }
    }

    func persistSelection() {
        let defaults = UserDefaults(suiteName: AppSecrets.shared.appGroupId) ?? .standard
        if let data = try? PropertyListEncoder().encode(selection) {
            defaults.set(data, forKey: "omni.family.selection")
        }
    }

    func loadSelection() {
        let defaults = UserDefaults(suiteName: AppSecrets.shared.appGroupId) ?? .standard
        guard let data = defaults.data(forKey: "omni.family.selection"),
              let decoded = try? PropertyListDecoder().decode(FamilyActivitySelection.self, from: data)
        else {
            return
        }

        selection = decoded
    }

    func startMonitoring(for block: PlanBlockDTO, enabled: Bool) {
        guard enabled else { return }
        guard authorizationStatus == .approved else { return }
        guard let startDate = block.startDate, let endDate = block.endDate else { return }

        let calendar = Calendar.current
        let startComponents = calendar.dateComponents([.hour, .minute], from: startDate)
        let endComponents = calendar.dateComponents([.hour, .minute], from: endDate)

        let schedule = DeviceActivitySchedule(
            intervalStart: startComponents,
            intervalEnd: endComponents,
            repeats: false
        )

        let event = DeviceActivityEvent(
            applications: selection.applicationTokens,
            categories: selection.categoryTokens,
            webDomains: selection.webDomainTokens,
            threshold: DateComponents(minute: 5)
        )

        let defaults = UserDefaults(suiteName: AppSecrets.shared.appGroupId) ?? .standard
        defaults.set(block.id, forKey: "omni.current.block.id")

        let activityName = DeviceActivityName("omni.focus.\(block.effectiveId)")
        do {
            try activityCenter.startMonitoring(
                activityName,
                during: schedule,
                events: [.driftThreshold: event]
            )
        } catch {
            lastError = error.localizedDescription
        }
    }
}

@MainActor
final class AppState: ObservableObject {
    @Published var session: OmniSession?
    @Published var isAuthenticated = false
    @Published var onboardingComplete = UserDefaults.standard.bool(forKey: StorageKeys.onboardingComplete)
    @Published var selectedTab = 0
    @Published var plan: PlanDTO?
    @Published var tasks: [TaskDTO] = []
    @Published var profile: UserProfileDTO?
    @Published var latestNudge: NudgeDTO?
    @Published var breakdown: BreakdownDTO?
    @Published var latestDayClose: DayCloseResponseDTO?
    @Published var errorMessage: String?

    @Published var driftSignalsToday = 0
    @Published var checkinsToday = 0

    @Published var screenTimeEnabled = UserDefaults.standard.bool(forKey: StorageKeys.screenTimeEnabled)

    let api = APIClient(baseURL: AppSecrets.shared.apiBaseURL)
    let auth = SupabaseOAuthService()
    let notifications = NotificationManager()
    var screenTimeManager = ScreenTimeManager()

    func bootstrap() {
        session = auth.restoreSession()
        isAuthenticated = session != nil
        screenTimeManager.loadSelection()

        if isAuthenticated {
            Task {
                await loadProfile()
                await refreshToday()
                await refreshTasks()
                await flushSharedDriftEvents()
                await notifications.requestPermission()
            }
        }
    }

    func signInWithApple() async {
        do {
            let session = try await auth.signInWithApple()
            self.session = session
            isAuthenticated = true
            await loadProfile()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func signOut() {
        session = nil
        isAuthenticated = false
        onboardingComplete = false
        UserDefaults.standard.set(false, forKey: StorageKeys.onboardingComplete)
        auth.clearSession()
        plan = nil
        tasks = []
        profile = nil
    }

    func connectGoogle() async -> Bool {
        guard let token = session?.accessToken else { return false }

        do {
            let startURL = try await api.startGoogleOAuth(
                accessToken: token,
                callbackScheme: AppSecrets.shared.oauthCallbackScheme
            )
            let runner = WebAuthSessionRunner()
            let callbackURL = try await runner.run(url: startURL, callbackScheme: AppSecrets.shared.oauthCallbackScheme)

            guard
                let components = URLComponents(url: callbackURL, resolvingAgainstBaseURL: false),
                components.queryItems?.first(where: { $0.name == "success" })?.value == "1"
            else {
                throw OmniAPIError.server("Google OAuth callback did not report success")
            }

            _ = try await api.fetchTasks(accessToken: token)
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    func generateDay(energy: String) async {
        guard let token = session?.accessToken else { return }
        do {
            let date = Self.todayString
            let generated = try await api.generatePlan(accessToken: token, date: date, energy: energy)
            self.plan = generated

            let cadence = profile?.checkinCadenceMinutes ?? 60
            notifications.scheduleForPlan(generated, checkinCadenceMinutes: cadence)

            if screenTimeEnabled, let focusBlock = currentFocusBlock() {
                screenTimeManager.startMonitoring(for: focusBlock, enabled: true)
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func refreshToday() async {
        guard let token = session?.accessToken else { return }
        do {
            plan = try await api.todayPlan(accessToken: token)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func refreshTasks() async {
        guard let token = session?.accessToken else { return }
        do {
            tasks = try await api.fetchTasks(accessToken: token)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func complete(taskId: String) async {
        guard let token = session?.accessToken else { return }
        do {
            _ = try await api.completeTask(accessToken: token, taskId: taskId)
            await refreshTasks()
            await refreshToday()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func createQuickTask(title: String) async {
        guard let token = session?.accessToken else { return }
        guard title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false else { return }

        do {
            _ = try await api.createTask(accessToken: token, title: title)
            await refreshTasks()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func sendCheckin(block: PlanBlockDTO, progress: Double, focus: Double) async {
        guard let token = session?.accessToken else { return }
        guard let blockId = block.id else { return }

        do {
            let _ = try await api.sendCheckin(
                accessToken: token,
                planBlockId: blockId,
                progress: progress,
                focus: focus,
                energy: nil
            )
            checkinsToday += 1
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func sendDrift(block: PlanBlockDTO?) async {
        guard let token = session?.accessToken else { return }

        do {
            let response = try await api.sendDrift(
                accessToken: token,
                planBlockId: block?.id,
                minutes: 5,
                apps: ["manual"]
            )
            driftSignalsToday += 1

            if block?.id != nil {
                latestNudge = try await api.requestNudge(
                    accessToken: token,
                    planBlockId: block!.id!,
                    triggerType: "drift",
                    payload: ["source": "manual"]
                )
            } else if response["nudge"] != nil {
                // no-op; structured nudge is fetched by explicit call above
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func requestSwap(block: PlanBlockDTO) async {
        guard let token = session?.accessToken else { return }
        guard let blockId = block.id else { return }

        do {
            latestNudge = try await api.requestNudge(
                accessToken: token,
                planBlockId: blockId,
                triggerType: "manual",
                payload: ["intent": "swap"]
            )
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func requestBreakdown(block: PlanBlockDTO) async {
        guard let token = session?.accessToken else { return }

        do {
            breakdown = try await api.requestBreakdown(
                accessToken: token,
                taskId: block.googleTaskId,
                title: block.label,
                dueAt: block.endAt
            )
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func savePreferences(coachMode: String, cadence: Int, sleepTime: String?, wakeTime: String?) async {
        guard let token = session?.accessToken else { return }

        do {
            _ = try await api.patchProfile(
                accessToken: token,
                body: PatchProfileInput(
                    coachMode: coachMode,
                    checkinCadenceMinutes: cadence,
                    sleepTime: sleepTime,
                    wakeTime: wakeTime
                )
            )
            await loadProfile()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func loadProfile() async {
        guard let token = session?.accessToken else { return }

        do {
            profile = try await api.profile(accessToken: token)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func closeDay(completedOutcomes: [String], biggestBlocker: String?, energyEnd: String?, notes: String?) async {
        guard let token = session?.accessToken else { return }

        do {
            latestDayClose = try await api.dayClose(
                accessToken: token,
                date: Self.todayString,
                completedOutcomes: completedOutcomes,
                biggestBlocker: biggestBlocker,
                energyEnd: energyEnd,
                notes: notes
            )
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func disconnectGoogle() async {
        guard let token = session?.accessToken else { return }
        do {
            try await api.disconnectGoogle(accessToken: token)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func setOnboardingComplete() {
        onboardingComplete = true
        UserDefaults.standard.set(true, forKey: StorageKeys.onboardingComplete)
    }

    func setScreenTimeEnabled(_ enabled: Bool) {
        screenTimeEnabled = enabled
        UserDefaults.standard.set(enabled, forKey: StorageKeys.screenTimeEnabled)
    }

    func flushSharedDriftEvents() async {
        let events = DriftEventStore.readAll()
        guard events.isEmpty == false else { return }
        guard let token = session?.accessToken else { return }

        for event in events {
            _ = try? await api.sendDrift(
                accessToken: token,
                planBlockId: event.blockId,
                minutes: event.minutes,
                apps: event.apps
            )
            driftSignalsToday += 1
        }

        DriftEventStore.clear()
    }

    func currentFocusBlock() -> PlanBlockDTO? {
        guard let plan else { return nil }
        let now = Date()
        return plan.blocks.first { block in
            guard let start = block.startDate, let end = block.endDate else { return false }
            return start <= now && now <= end
        }
    }

    static var todayString: String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: Date())
    }
}

@main
struct OmniApp: App {
    @StateObject private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            Group {
                if appState.isAuthenticated == false {
                    AuthView()
                        .environmentObject(appState)
                } else if appState.onboardingComplete == false {
                    OnboardingFlowView()
                        .environmentObject(appState)
                } else {
                    MainTabView()
                        .environmentObject(appState)
                }
            }
            .task {
                appState.bootstrap()
            }
            .onOpenURL { url in
                if url.host == "now" {
                    appState.selectedTab = 0
                }
                Task {
                    await appState.flushSharedDriftEvents()
                }
            }
            .alert("Error", isPresented: Binding(
                get: { appState.errorMessage != nil },
                set: { newValue in if !newValue { appState.errorMessage = nil } }
            )) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(appState.errorMessage ?? "Unknown error")
            }
        }
    }
}

struct AuthView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        VStack(spacing: 24) {
            Text("Omni")
                .font(.largeTitle.bold())

            Text("Sign in to start planning your day")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Button("Sign in with Apple") {
                Task { await appState.signInWithApple() }
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
    }
}

struct OnboardingFlowView: View {
    @EnvironmentObject var appState: AppState
    @State private var step = 0
    @State private var energy = "med"
    @State private var coachMode = UserDefaults.standard.string(forKey: StorageKeys.coachMode) ?? "balanced"
    @State private var cadence = UserDefaults.standard.integer(forKey: StorageKeys.checkinCadence)
    @State private var sleepTime = ""
    @State private var wakeTime = ""
    @State private var showPicker = false

    private let energies = ["low", "med", "high"]

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 20) {
                ProgressView(value: Double(step + 1), total: 5)

                switch step {
                case 0:
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Welcome to Omni")
                            .font(.title2.bold())
                        Text("Calendar + tasks + focus nudges.")
                            .foregroundStyle(.secondary)
                        Button("Continue") { step += 1 }
                            .buttonStyle(.borderedProminent)
                    }

                case 1:
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Connect Google")
                            .font(.title2.bold())
                        Text("Required for Calendar and Tasks sync")
                            .foregroundStyle(.secondary)

                        Button("Connect Google") {
                            Task {
                                if await appState.connectGoogle() {
                                    step += 1
                                }
                            }
                        }
                        .buttonStyle(.borderedProminent)
                    }

                case 2:
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Screen Time Setup")
                            .font(.title2.bold())
                        Text("Select distracting apps. If denied, manual drift still works.")
                            .foregroundStyle(.secondary)

                        Button("Authorize Screen Time") {
                            Task { await appState.screenTimeManager.requestAuthorization() }
                        }

                        Button("Pick Apps") { showPicker = true }
                            .disabled(appState.screenTimeManager.authorizationStatus != .approved)

                        Button("Continue") {
                            appState.screenTimeManager.persistSelection()
                            step += 1
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .familyActivityPicker(isPresented: $showPicker, selection: $appState.screenTimeManager.selection)

                case 3:
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Preferences")
                            .font(.title2.bold())

                        Picker("Coach Mode", selection: $coachMode) {
                            Text("Gentle").tag("gentle")
                            Text("Balanced").tag("balanced")
                            Text("Strict").tag("strict")
                        }
                        .pickerStyle(.segmented)

                        Stepper("Check-in cadence: \(cadence <= 0 ? 60 : cadence) min", value: $cadence, in: 15...180, step: 15)

                        TextField("Sleep (optional, e.g. 23:00)", text: $sleepTime)
                            .textFieldStyle(.roundedBorder)
                        TextField("Wake (optional, e.g. 07:00)", text: $wakeTime)
                            .textFieldStyle(.roundedBorder)

                        Button("Save & Continue") {
                            Task {
                                let realCadence = cadence <= 0 ? 60 : cadence
                                UserDefaults.standard.set(coachMode, forKey: StorageKeys.coachMode)
                                UserDefaults.standard.set(realCadence, forKey: StorageKeys.checkinCadence)
                                await appState.savePreferences(
                                    coachMode: coachMode,
                                    cadence: realCadence,
                                    sleepTime: sleepTime.isEmpty ? nil : sleepTime,
                                    wakeTime: wakeTime.isEmpty ? nil : wakeTime
                                )
                                step += 1
                            }
                        }
                        .buttonStyle(.borderedProminent)
                    }

                default:
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Generate My Day")
                            .font(.title2.bold())

                        Picker("Energy", selection: $energy) {
                            ForEach(energies, id: \.self) { value in
                                Text(value.uppercased()).tag(value)
                            }
                        }
                        .pickerStyle(.segmented)

                        Button("Generate My Day") {
                            Task {
                                await appState.generateDay(energy: energy)
                                appState.setOnboardingComplete()
                            }
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }

                Spacer()
            }
            .padding()
            .navigationTitle("Onboarding")
        }
    }
}

struct MainTabView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        TabView(selection: $appState.selectedTab) {
            NavigationStack { NowView() }
                .tabItem { Label("Now", systemImage: "bolt.fill") }
                .tag(0)

            NavigationStack { TodayView() }
                .tabItem { Label("Today", systemImage: "calendar") }
                .tag(1)

            NavigationStack { TasksView() }
                .tabItem { Label("Tasks", systemImage: "checklist") }
                .tag(2)

            NavigationStack { InsightsView() }
                .tabItem { Label("Insights", systemImage: "chart.bar") }
                .tag(3)

            NavigationStack { SettingsView() }
                .tabItem { Label("Settings", systemImage: "gearshape") }
                .tag(4)
        }
        .task {
            await appState.refreshToday()
            await appState.refreshTasks()
            await appState.flushSharedDriftEvents()
        }
    }
}

struct NowView: View {
    @EnvironmentObject var appState: AppState
    @State private var progress = 50.0
    @State private var focus = 3.0

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if let block = appState.currentFocusBlock() {
                    Text(block.label)
                        .font(.title2.bold())

                    Text("Ends: \(block.endDate?.formatted(date: .omitted, time: .shortened) ?? "-")")
                        .foregroundStyle(.secondary)

                    Text(block.rationale)
                        .font(.footnote)
                        .foregroundStyle(.secondary)

                    BlockActionCard(block: block, progress: $progress, focus: $focus)
                } else {
                    Text("No active block")
                        .font(.title3.bold())
                    Text("Open Today tab or generate plan.")
                        .foregroundStyle(.secondary)
                }

                if let nudge = appState.latestNudge {
                    NudgeCard(nudge: nudge)
                }

                if let breakdown = appState.breakdown {
                    BreakdownCard(breakdown: breakdown)
                }
            }
            .padding()
        }
        .navigationTitle("Now")
    }
}

struct TodayView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        List {
            if let plan = appState.plan {
                Section("Top Outcomes") {
                    ForEach(plan.topOutcomes, id: \.self) { outcome in
                        Text(outcome)
                    }
                }

                Section("Timeline") {
                    ForEach(plan.blocks, id: \.effectiveId) { block in
                        NavigationLink {
                            BlockDetailView(block: block)
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(block.label)
                                Text("\(block.startDate?.formatted(date: .omitted, time: .shortened) ?? "-") - \(block.endDate?.formatted(date: .omitted, time: .shortened) ?? "-")")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            } else {
                Text("No plan yet")
            }
        }
        .navigationTitle("Today")
        .toolbar {
            Button("Refresh") {
                Task { await appState.refreshToday() }
            }
        }
    }
}

struct BlockDetailView: View {
    @EnvironmentObject var appState: AppState
    let block: PlanBlockDTO
    @State private var progress = 40.0
    @State private var focus = 3.0

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Text(block.label)
                    .font(.title3.bold())
                Text(block.rationale)
                    .foregroundStyle(.secondary)

                BlockActionCard(block: block, progress: $progress, focus: $focus)

                if let nudge = appState.latestNudge {
                    NudgeCard(nudge: nudge)
                }
                if let breakdown = appState.breakdown {
                    BreakdownCard(breakdown: breakdown)
                }
            }
            .padding()
        }
    }
}

struct TasksView: View {
    @EnvironmentObject var appState: AppState
    @State private var quickTask = ""

    var body: some View {
        List {
            Section("Quick Task") {
                HStack {
                    TextField("Add quick task", text: $quickTask)
                    Button("Add") {
                        Task {
                            await appState.createQuickTask(title: quickTask)
                            quickTask = ""
                        }
                    }
                }
            }

            Section("Google Tasks") {
                ForEach(appState.tasks) { task in
                    HStack {
                        VStack(alignment: .leading) {
                            Text(task.title)
                            Text(task.status)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()

                        if task.status != "completed" {
                            Button("Done") {
                                Task { await appState.complete(taskId: task.id) }
                            }
                            .buttonStyle(.bordered)
                        }
                    }
                }
            }
        }
        .navigationTitle("Tasks")
        .task { await appState.refreshTasks() }
    }
}

struct InsightsView: View {
    @EnvironmentObject var appState: AppState
    @State private var blocker = ""
    @State private var notes = ""

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Text("Today")
                    .font(.title2.bold())

                Text("Drift signals: \(appState.driftSignalsToday)")
                Text("Check-ins: \(appState.checkinsToday)")
                Text("Completed tasks: \(appState.tasks.filter { $0.status == "completed" }.count)")

                Divider()

                Text("Day Close")
                    .font(.headline)

                TextField("Biggest blocker", text: $blocker)
                    .textFieldStyle(.roundedBorder)
                TextField("Notes", text: $notes)
                    .textFieldStyle(.roundedBorder)

                Button("Generate Day Close") {
                    Task {
                        let outcomes = appState.plan?.topOutcomes ?? []
                        await appState.closeDay(
                            completedOutcomes: outcomes,
                            biggestBlocker: blocker.isEmpty ? nil : blocker,
                            energyEnd: "med",
                            notes: notes.isEmpty ? nil : notes
                        )
                    }
                }
                .buttonStyle(.borderedProminent)

                if let close = appState.latestDayClose {
                    Text(close.summary)
                        .padding(.top, 8)
                    Text("Tomorrow Top 3")
                        .font(.subheadline.bold())
                    ForEach(close.tomorrowTop3, id: \.self) { item in
                        Text("• \(item)")
                    }
                }
            }
            .padding()
        }
        .navigationTitle("Insights")
    }
}

struct SettingsView: View {
    @EnvironmentObject var appState: AppState
    @State private var coachMode = UserDefaults.standard.string(forKey: StorageKeys.coachMode) ?? "balanced"
    @State private var cadence = UserDefaults.standard.integer(forKey: StorageKeys.checkinCadence)
    @State private var showPicker = false

    var body: some View {
        Form {
            Section("Coach") {
                Picker("Coach Mode", selection: $coachMode) {
                    Text("Gentle").tag("gentle")
                    Text("Balanced").tag("balanced")
                    Text("Strict").tag("strict")
                }

                Stepper("Check-in cadence: \(cadence <= 0 ? 60 : cadence) min", value: $cadence, in: 15...180, step: 15)

                Button("Save") {
                    Task {
                        let value = cadence <= 0 ? 60 : cadence
                        UserDefaults.standard.set(coachMode, forKey: StorageKeys.coachMode)
                        UserDefaults.standard.set(value, forKey: StorageKeys.checkinCadence)
                        await appState.savePreferences(coachMode: coachMode, cadence: value, sleepTime: nil, wakeTime: nil)
                    }
                }
            }

            Section("Google") {
                Button("Disconnect Google", role: .destructive) {
                    Task { await appState.disconnectGoogle() }
                }
            }

            Section("Screen Time") {
                Toggle("Screen Time drift enabled", isOn: Binding(
                    get: { appState.screenTimeEnabled },
                    set: { appState.setScreenTimeEnabled($0) }
                ))

                Button("Request Authorization") {
                    Task { await appState.screenTimeManager.requestAuthorization() }
                }

                Button("Re-pick distracting apps") {
                    showPicker = true
                }
                .disabled(appState.screenTimeManager.authorizationStatus != .approved)
            }

            Section("Session") {
                Button("Sign Out", role: .destructive) {
                    appState.signOut()
                }
            }
        }
        .familyActivityPicker(isPresented: $showPicker, selection: $appState.screenTimeManager.selection)
        .navigationTitle("Settings")
    }
}

struct BlockActionCard: View {
    @EnvironmentObject var appState: AppState
    let block: PlanBlockDTO
    @Binding var progress: Double
    @Binding var focus: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Button("✅ Done") {
                Task {
                    if let taskId = block.googleTaskId {
                        await appState.complete(taskId: taskId)
                    } else {
                        await appState.sendCheckin(block: block, progress: 100, focus: 4)
                    }
                }
            }
            .buttonStyle(.borderedProminent)

            VStack(alignment: .leading) {
                Text("Progress: \(Int(progress))%")
                Slider(value: $progress, in: 0...100)
                Text("Focus: \(Int(focus))/5")
                Slider(value: $focus, in: 1...5, step: 1)

                Button("🟡 Not Done (check-in)") {
                    Task {
                        await appState.sendCheckin(block: block, progress: progress, focus: focus)
                    }
                }
            }

            Button("🔥 I’m drifting") {
                Task { await appState.sendDrift(block: block) }
            }

            Button("🔄 Swap me") {
                Task { await appState.requestSwap(block: block) }
            }

            Button("🧩 Break into steps") {
                Task { await appState.requestBreakdown(block: block) }
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

struct NudgeCard: View {
    let nudge: NudgeDTO

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Nudge: \(nudge.recommendedAction.capitalized)")
                .font(.headline)
            Text(nudge.rationale)
                .font(.subheadline)
            ForEach(nudge.alternatives, id: \.self) { alt in
                Text("• \(alt)")
                    .font(.caption)
            }
        }
        .padding()
        .background(Color(.tertiarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

struct BreakdownCard: View {
    let breakdown: BreakdownDTO

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Subtasks")
                .font(.headline)

            ForEach(breakdown.subtasks, id: \.self) { subtask in
                Text("\(subtask.order + 1). \(subtask.title) (\(subtask.estimatedMinutes)m)")
                    .font(.caption)
            }
        }
        .padding()
        .background(Color(.tertiarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

extension JSONDecoder {
    static var omni: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return decoder
    }
}

extension ISO8601DateFormatter {
    static var omni: ISO8601DateFormatter {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }
}

extension DeviceActivityEvent.Name {
    static let driftThreshold = Self("driftThreshold")
}
