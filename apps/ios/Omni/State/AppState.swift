import Foundation
import SwiftUI

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

    func signInWithEmail(email: String, password: String) async {
        do {
            let session = try await auth.signInWithEmail(email: email, password: password)
            self.session = session
            isAuthenticated = true
            await loadProfile()
        } catch {
            handleError(error)
        }
    }

    func signUpWithEmail(email: String, password: String) async {
        do {
            let session = try await auth.signUpWithEmail(email: email, password: password)
            self.session = session
            isAuthenticated = true
            await loadProfile()
        } catch {
            handleError(error)
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
            handleError(error)
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
            handleError(error)
        }
    }

    func refreshToday() async {
        guard let token = session?.accessToken else { return }
        do {
            plan = try await api.todayPlan(accessToken: token)
        } catch {
            handleError(error)
        }
    }

    func refreshTasks() async {
        guard let token = session?.accessToken else { return }
        do {
            tasks = try await api.fetchTasks(accessToken: token)
        } catch {
            handleError(error)
        }
    }

    func complete(taskId: String) async {
        guard let token = session?.accessToken else { return }
        do {
            _ = try await api.completeTask(accessToken: token, taskId: taskId)
            await refreshTasks()
            await refreshToday()
        } catch {
            handleError(error)
        }
    }

    func createQuickTask(title: String) async {
        guard let token = session?.accessToken else { return }
        guard title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false else { return }

        do {
            _ = try await api.createTask(accessToken: token, title: title)
            await refreshTasks()
        } catch {
            handleError(error)
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
            handleError(error)
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
            handleError(error)
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
            handleError(error)
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
            handleError(error)
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
            handleError(error)
        }
    }

    func loadProfile() async {
        guard let token = session?.accessToken else { return }

        do {
            profile = try await api.profile(accessToken: token)
        } catch {
            handleError(error)
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
            handleError(error)
        }
    }

    func disconnectGoogle() async {
        guard let token = session?.accessToken else { return }
        do {
            try await api.disconnectGoogle(accessToken: token)
        } catch {
            handleError(error)
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

    private func handleError(_ error: Error) {
        guard error.isOmniCancellation == false else {
            return
        }

        if let apiError = error as? OmniAPIError, let description = apiError.errorDescription {
            errorMessage = description
            return
        }

        errorMessage = error.localizedDescription
    }

    static var todayString: String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: Date())
    }
}
