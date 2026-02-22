import Foundation
import SwiftUI
import Combine

@MainActor
enum OmniTab: Int, CaseIterable {
    case dashboard = 0
    case calendar = 1
    case feedback = 2
    case reward = 3
    case settings = 4

    var title: String {
        switch self {
        case .dashboard: return "Dashboard"
        case .calendar: return "Calendar"
        case .feedback: return "Feedback"
        case .reward: return "Reward"
        case .settings: return "Settings"
        }
    }

    var icon: String {
        switch self {
        case .dashboard: return "house"
        case .calendar: return "calendar"
        case .feedback: return "waveform.path.ecg"
        case .reward: return "trophy"
        case .settings: return "gearshape"
        }
    }
}

@MainActor
final class AppRouter: ObservableObject {
    @Published var selectedTab: OmniTab {
        didSet {
            UserDefaults.standard.set(selectedTab.rawValue, forKey: StorageKeys.selectedTab)
        }
    }

    init() {
        let saved = UserDefaults.standard.integer(forKey: StorageKeys.selectedTab)
        selectedTab = OmniTab(rawValue: saved) ?? .dashboard
    }

    func handle(url: URL) {
        guard url.scheme?.lowercased() == "omni" else { return }

        switch url.host?.lowercased() {
        case "dashboard", "now":
            selectedTab = .dashboard
        case "calendar":
            selectedTab = .calendar
        case "feedback":
            selectedTab = .feedback
        case "reward":
            selectedTab = .reward
        case "settings":
            selectedTab = .settings
        default:
            selectedTab = .dashboard
        }
    }
}

@MainActor
final class SessionStore: ObservableObject {
    @Published var session: OmniSession?
    @Published var onboardingComplete = UserDefaults.standard.bool(forKey: StorageKeys.onboardingComplete)

    var isAuthenticated: Bool {
        session != nil
    }

    func bootstrap(auth: SupabaseOAuthService) {
        session = auth.restoreSession()
    }

    func signIn(auth: SupabaseOAuthService, email: String, password: String) async throws {
        session = try await auth.signInWithEmail(email: email, password: password)
    }

    func signUp(auth: SupabaseOAuthService, email: String, password: String) async throws {
        session = try await auth.signUpWithEmail(email: email, password: password)
    }

    func markOnboardingComplete() {
        onboardingComplete = true
        UserDefaults.standard.set(true, forKey: StorageKeys.onboardingComplete)
    }

    func resetOnboarding() {
        onboardingComplete = false
        UserDefaults.standard.set(false, forKey: StorageKeys.onboardingComplete)
    }

    func signOut(auth: SupabaseOAuthService) {
        session = nil
        resetOnboarding()
        auth.clearSession()
    }
}

@MainActor
final class PlanStore: ObservableObject {
    @Published var plan: PlanDTO?
    @Published private(set) var snapshots: [String: BlockProgressSnapshot] = [:]

    private var planCache: [String: PlanDTO] = [:]

    func clear() {
        plan = nil
        snapshots = [:]
        planCache = [:]
    }

    func refreshToday(api: APIClient, token: String) async throws {
        let fetched = try await api.todayPlan(accessToken: token)
        plan = fetched
        if let fetched {
            planCache[fetched.planDate] = fetched
        }
    }

    func refresh(date: String, api: APIClient, token: String) async throws -> PlanDTO? {
        if let cached = planCache[date] {
            return cached
        }

        let fetched = try await api.plan(accessToken: token, date: date)
        if let fetched {
            planCache[fetched.planDate] = fetched
        }
        return fetched
    }

    func setGeneratedPlan(_ generated: PlanDTO) {
        plan = generated
        planCache[generated.planDate] = generated
    }

    func currentBlock(now: Date = Date()) -> PlanBlockDTO? {
        guard let plan else { return nil }

        if let active = plan.blocks.first(where: { block in
            guard let start = block.startDate, let end = block.endDate else { return false }
            return start <= now && now <= end && block.type != "break"
        }) {
            return active
        }

        if let next = plan.blocks.first(where: { block in
            guard let start = block.startDate else { return false }
            return start > now && block.type != "break"
        }) {
            return next
        }

        return plan.blocks.first(where: { block in
            guard block.type != "break", let blockId = block.id else { return false }
            return (snapshots[blockId]?.progress ?? 0) < 100
        })
    }

    func nextTaskBlock(after now: Date = Date()) -> PlanBlockDTO? {
        guard let plan else { return nil }
        let sorted = plan.blocks.sorted { ($0.startDate ?? .distantFuture) < ($1.startDate ?? .distantFuture) }
        return sorted.first { block in
            guard block.type != "break", let start = block.startDate else { return false }
            return start > now
        }
    }

    func progress(for block: PlanBlockDTO) -> Double? {
        guard let blockId = block.id else { return nil }
        return snapshots[blockId]?.progress
    }

    func focus(for block: PlanBlockDTO) -> Double? {
        guard let blockId = block.id else { return nil }
        return snapshots[blockId]?.focus
    }

    func updateSnapshot(blockId: String, progress: Double, focus: Double) {
        snapshots[blockId] = BlockProgressSnapshot(
            blockId: blockId,
            progress: max(0, min(100, progress)),
            focus: max(1, min(10, focus)),
            updatedAt: Date()
        )
    }

    func optimisticComplete(block: PlanBlockDTO) {
        guard let blockId = block.id else { return }
        let currentFocus = snapshots[blockId]?.focus ?? 7
        updateSnapshot(blockId: blockId, progress: 100, focus: currentFocus)
    }

    func timelineItems(for date: String, events: [CalendarEventDTO]) -> [CalendarTimelineItem] {
        let planItems: [CalendarTimelineItem] = (plan?.blocks ?? [])
            .filter { $0.startAt.hasPrefix(date) }
            .compactMap { block in
                guard let start = block.startDate, let end = block.endDate else { return nil }

                let title: String
                if block.type == "break" {
                    title = "Break (Omni)"
                } else {
                    title = "Study Session (Omni)"
                }

                return CalendarTimelineItem(
                    id: "plan-\(block.effectiveId)",
                    source: .plan,
                    title: title,
                    subtitle: block.label,
                    start: start,
                    end: end,
                    planBlock: block,
                    event: nil
                )
            }

        let eventItems: [CalendarTimelineItem] = events.compactMap { event in
            guard let start = event.startDate, let end = event.endDate else { return nil }
            return CalendarTimelineItem(
                id: "event-\(event.sourceId)",
                source: .calendar,
                title: event.title,
                subtitle: event.location,
                start: start,
                end: end,
                planBlock: nil,
                event: event
            )
        }

        return (planItems + eventItems).sorted { $0.start < $1.start }
    }
}

@MainActor
final class GoogleStore: ObservableObject {
    @Published var tasks: [TaskDTO] = []
    @Published var taskLists: [TaskListDTO] = []
    @Published private(set) var eventsByDate: [String: [CalendarEventDTO]] = [:]

    func clear() {
        tasks = []
        taskLists = []
        eventsByDate = [:]
    }

    func refreshTasks(api: APIClient, token: String) async throws {
        tasks = try await api.fetchTasks(accessToken: token)
    }

    func refreshTaskLists(api: APIClient, token: String) async throws {
        taskLists = try await api.fetchTaskLists(accessToken: token)
    }

    func refreshEvents(for date: String, api: APIClient, token: String) async throws {
        let events = try await api.calendarEvents(accessToken: token, date: date)
        eventsByDate[date] = events
    }

    func events(for date: String) -> [CalendarEventDTO] {
        eventsByDate[date] ?? []
    }

    func nextUpcomingEvent(after now: Date = Date(), on date: String) -> CalendarEventDTO? {
        events(for: date)
            .compactMap { event -> (CalendarEventDTO, Date)? in
                guard let start = event.startDate else { return nil }
                return (event, start)
            }
            .filter { $0.1 > now }
            .sorted { $0.1 < $1.1 }
            .first?
            .0
    }

    func completeTask(taskId: String, api: APIClient, token: String) async throws {
        let completed = try await api.completeTask(accessToken: token, taskId: taskId)
        if let index = tasks.firstIndex(where: { $0.id == taskId }) {
            tasks[index] = completed
        }
    }

    func createTask(
        title: String,
        dueAt: String?,
        estimatedMinutes: Int?,
        api: APIClient,
        token: String
    ) async throws {
        let created = try await api.createTask(
            accessToken: token,
            title: title,
            dueAt: dueAt,
            estimatedMinutes: estimatedMinutes
        )
        tasks.insert(created, at: 0)
    }
}

@MainActor
final class SignalsStore: ObservableObject {
    @Published var latestNudge: NudgeDTO?
    @Published var latestBreakdown: BreakdownDTO?
    @Published var driftEventsToday: Int = 0
    @Published var checkinsToday: Int = 0
    @Published var activeFocusSession: FocusSessionState?

    func clear() {
        latestNudge = nil
        latestBreakdown = nil
        driftEventsToday = 0
        checkinsToday = 0
        activeFocusSession = nil
    }

    func startFocusSession(
        block: PlanBlockDTO,
        cadenceMinutes: Int,
        api: APIClient,
        token: String,
        notifications: NotificationManager
    ) async throws {
        let plannedMinutes = max(1, Int((block.endDate?.timeIntervalSince(block.startDate ?? Date()) ?? 0) / 60))
        _ = try await api.focusSessionStart(
            accessToken: token,
            planBlockId: block.id,
            plannedMinutes: plannedMinutes
        )

        if let blockId = block.id {
            activeFocusSession = FocusSessionState(blockId: blockId, start: Date(), plannedMinutes: plannedMinutes)
        }
        notifications.scheduleNextCheckin(for: block, cadenceMinutes: cadenceMinutes)
    }

    func submitCheckin(
        block: PlanBlockDTO,
        done: Bool,
        progress: Double,
        focus: Double,
        energy: String?,
        happenedTags: [String],
        derailReason: String?,
        driftMinutes: Int?,
        api: APIClient,
        token: String
    ) async throws -> SignalWriteResponseDTO {
        guard let blockId = block.id else {
            throw OmniAPIError.server("Current block is missing an id")
        }

        let response = try await api.sendCheckin(
            accessToken: token,
            planBlockId: blockId,
            done: done,
            progress: progress,
            focus: focus,
            energy: energy,
            happenedTags: happenedTags,
            derailReason: derailReason,
            driftMinutes: driftMinutes
        )

        checkinsToday += 1
        if let nudge = response.nudge {
            latestNudge = nudge
        }

        return response
    }

    func submitDrift(
        block: PlanBlockDTO?,
        minutes: Int,
        derailReason: String?,
        api: APIClient,
        token: String
    ) async throws -> SignalWriteResponseDTO {
        let response = try await api.sendDrift(
            accessToken: token,
            planBlockId: block?.id,
            minutes: minutes,
            derailReason: derailReason,
            apps: ["manual"]
        )

        driftEventsToday += 1
        if let nudge = response.nudge {
            latestNudge = nudge
        }

        return response
    }

    func requestSwap(
        block: PlanBlockDTO,
        api: APIClient,
        token: String
    ) async throws {
        guard let blockId = block.id else {
            throw OmniAPIError.server("Current block is missing an id")
        }

        latestNudge = try await api.requestNudge(
            accessToken: token,
            planBlockId: blockId,
            triggerType: "manual",
            payload: ["intent": "swap"]
        )
    }

    func requestBreakdown(
        block: PlanBlockDTO,
        api: APIClient,
        token: String
    ) async throws {
        latestBreakdown = try await api.requestBreakdown(
            accessToken: token,
            taskId: block.googleTaskId,
            title: block.label,
            dueAt: block.endAt
        )
    }
}

@MainActor
final class InsightsStore: ObservableObject {
    @Published var today: InsightsTodayDTO?
    @Published var latestDayClose: DayCloseResponseDTO?

    func clear() {
        today = nil
        latestDayClose = nil
    }

    func refreshToday(api: APIClient, token: String, date: String? = nil) async throws {
        today = try await api.insightsToday(accessToken: token, date: date)
    }

    func closeDay(
        api: APIClient,
        token: String,
        date: String,
        completedOutcomes: [String],
        biggestBlocker: String?,
        energyEnd: String?,
        notes: String?
    ) async throws {
        latestDayClose = try await api.dayClose(
            accessToken: token,
            date: date,
            completedOutcomes: completedOutcomes,
            biggestBlocker: biggestBlocker,
            energyEnd: energyEnd,
            notes: notes
        )
    }
}

@MainActor
final class RewardsStore: ObservableObject {
    @Published var weekly: RewardsWeeklyDTO?
    @Published var claimMessage: String?

    func clear() {
        weekly = nil
        claimMessage = nil
    }

    func refreshWeekly(api: APIClient, token: String, date: String? = nil) async throws {
        weekly = try await api.rewardsWeekly(accessToken: token, date: date)
    }

    func claimWeekly(api: APIClient, token: String, date: String? = nil) async throws {
        let response = try await api.claimWeeklyReward(accessToken: token, date: date)
        claimMessage = response.message
    }
}

@MainActor
final class AppState: ObservableObject {
    @Published var errorMessage: String?
    @Published var profile: UserProfileDTO?
    @Published var integrationsStatus: IntegrationsStatusDTO?

    let api = APIClient(baseURL: AppSecrets.shared.apiBaseURL)
    let auth = SupabaseOAuthService()
    let notifications = NotificationManager()

    var router = AppRouter()
    let sessionStore = SessionStore()
    let planStore = PlanStore()
    let googleStore = GoogleStore()
    let signalsStore = SignalsStore()
    let insightsStore = InsightsStore()
    let rewardsStore = RewardsStore()

    private var didBootstrap = false
    private var cancellables = Set<AnyCancellable>()

    init() {
        router.$selectedTab
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)
    }

    var todayString: String {
        OmniDateParser.dayString(Date())
    }

    var displayName: String {
        "Omni User"
    }

    func bootstrap() {
        guard didBootstrap == false else { return }
        didBootstrap = true

        sessionStore.bootstrap(auth: auth)
        Task {
            await notifications.requestPermission()
            await refreshIfAuthenticated(fullRefresh: true)
        }
    }

    func handleDeepLink(_ url: URL) {
        router.handle(url: url)
    }

    func signInWithEmail(email: String, password: String) async {
        do {
            try await sessionStore.signIn(auth: auth, email: email, password: password)
            await refreshIfAuthenticated(fullRefresh: true)
        } catch {
            handleError(error)
        }
    }

    func signUpWithEmail(email: String, password: String) async {
        do {
            try await sessionStore.signUp(auth: auth, email: email, password: password)
            await refreshIfAuthenticated(fullRefresh: true)
        } catch {
            handleError(error)
        }
    }

    func signOut() {
        sessionStore.signOut(auth: auth)
        clearStores()
    }

    func connectGoogle() async -> Bool {
        guard let token = sessionStore.session?.accessToken else { return false }

        do {
            let startURL = try await api.startGoogleOAuth(
                accessToken: token,
                callbackScheme: AppSecrets.shared.oauthCallbackScheme
            )

            let runner = WebAuthSessionRunner()
            let callbackURL = try await runner.run(
                url: startURL,
                callbackScheme: AppSecrets.shared.oauthCallbackScheme
            )

            guard
                let components = URLComponents(url: callbackURL, resolvingAgainstBaseURL: false),
                components.queryItems?.first(where: { $0.name == "success" })?.value == "1"
            else {
                throw OmniAPIError.server("Google OAuth callback did not report success")
            }

            try await googleStore.refreshTasks(api: api, token: token)
            try await googleStore.refreshTaskLists(api: api, token: token)
            try await googleStore.refreshEvents(for: todayString, api: api, token: token)
            try await loadIntegrationsStatus(token: token)
            return true
        } catch {
            handleError(error)
            return false
        }
    }

    func generateDay(
        energy: String,
        mood: String? = nil,
        stickyBlocks: [String] = []
    ) async -> Bool {
        guard let token = sessionStore.session?.accessToken else {
            errorMessage = "Session expired. Please sign in again."
            return false
        }

        do {
            let trimmedMood = mood?
                .trimmingCharacters(in: .whitespacesAndNewlines)
            let dayOpen = OnboardingDayOpenProfile(
                lastEnergy: energy,
                lastMood: trimmedMood?.isEmpty == true ? nil : trimmedMood,
                updatedAt: ISO8601DateFormatter().string(from: Date())
            )

            let patchedProfile = try await api.patchProfile(
                accessToken: token,
                body: PatchProfileInput(
                    energyProfile: mergedOnboardingEnergyProfile(dayOpen: dayOpen)
                )
            )
            profile = patchedProfile

            let generated = try await api.generatePlan(
                accessToken: token,
                date: todayString,
                energy: energy,
                coachMode: patchedProfile.coachMode,
                stickyBlocks: stickyBlocks.isEmpty ? nil : stickyBlocks
            )
            planStore.setGeneratedPlan(generated)
            notifications.scheduleForPlan(generated, checkinCadenceMinutes: profile?.checkinCadenceMinutes ?? 60)
            try await googleStore.refreshEvents(for: todayString, api: api, token: token)
            try await insightsStore.refreshToday(api: api, token: token, date: todayString)
            try await rewardsStore.refreshWeekly(api: api, token: token)
            return true
        } catch {
            handleError(error)
            return false
        }
    }

    func refreshIfAuthenticated(fullRefresh: Bool = false) async {
        guard let token = sessionStore.session?.accessToken else { return }

        do {
            if fullRefresh {
                try await googleStore.refreshTaskLists(api: api, token: token)
            }

            try await loadProfile(token: token)
            try await loadIntegrationsStatus(token: token)
            try await planStore.refreshToday(api: api, token: token)
            try await googleStore.refreshTasks(api: api, token: token)
            try await googleStore.refreshEvents(for: todayString, api: api, token: token)
            try await insightsStore.refreshToday(api: api, token: token, date: todayString)
            try await rewardsStore.refreshWeekly(api: api, token: token)
        } catch {
            handleError(error)
        }
    }

    func refreshCalendar(date: Date) async {
        guard let token = sessionStore.session?.accessToken else { return }
        let day = OmniDateParser.dayString(date)

        do {
            _ = try await planStore.refresh(date: day, api: api, token: token)
            try await googleStore.refreshEvents(for: day, api: api, token: token)
        } catch {
            handleError(error)
        }
    }

    func startFocusSession(block: PlanBlockDTO) async {
        guard let token = sessionStore.session?.accessToken else { return }

        do {
            try await signalsStore.startFocusSession(
                block: block,
                cadenceMinutes: profile?.checkinCadenceMinutes ?? 60,
                api: api,
                token: token,
                notifications: notifications
            )
        } catch {
            handleError(error)
        }
    }

    func completeCurrentBlock(_ block: PlanBlockDTO) async {
        guard let token = sessionStore.session?.accessToken else { return }

        do {
            if let taskId = block.googleTaskId {
                try await googleStore.completeTask(taskId: taskId, api: api, token: token)
            }
            planStore.optimisticComplete(block: block)

            try await planStore.refreshToday(api: api, token: token)
            try await rewardsStore.refreshWeekly(api: api, token: token)
            try await insightsStore.refreshToday(api: api, token: token, date: todayString)
        } catch {
            handleError(error)
        }
    }

    func submitCheckin(
        block: PlanBlockDTO,
        done: Bool,
        progress: Double,
        focus: Double,
        energy: String?,
        happenedTags: [String],
        derailReason: String?,
        driftMinutes: Int?
    ) async {
        guard let token = sessionStore.session?.accessToken,
              let blockId = block.id
        else { return }

        planStore.updateSnapshot(blockId: blockId, progress: progress, focus: focus)

        do {
            _ = try await signalsStore.submitCheckin(
                block: block,
                done: done,
                progress: progress,
                focus: focus,
                energy: energy,
                happenedTags: happenedTags,
                derailReason: derailReason,
                driftMinutes: driftMinutes,
                api: api,
                token: token
            )

            if done {
                planStore.optimisticComplete(block: block)
            }

            try await insightsStore.refreshToday(api: api, token: token, date: todayString)
            try await rewardsStore.refreshWeekly(api: api, token: token)
        } catch {
            handleError(error)
        }
    }

    func submitDrift(block: PlanBlockDTO?, derailReason: String?) async {
        guard let token = sessionStore.session?.accessToken else { return }

        do {
            _ = try await signalsStore.submitDrift(
                block: block,
                minutes: 5,
                derailReason: derailReason,
                api: api,
                token: token
            )

            if let block, let blockId = block.id {
                signalsStore.latestNudge = try await api.requestNudge(
                    accessToken: token,
                    planBlockId: blockId,
                    triggerType: "drift",
                    payload: ["source": "manual"]
                )
            }

            try await insightsStore.refreshToday(api: api, token: token, date: todayString)
            try await rewardsStore.refreshWeekly(api: api, token: token)
        } catch {
            handleError(error)
        }
    }

    func requestSwap(block: PlanBlockDTO) async {
        guard let token = sessionStore.session?.accessToken else { return }

        do {
            try await signalsStore.requestSwap(block: block, api: api, token: token)
        } catch {
            handleError(error)
        }
    }

    func requestBreakdown(block: PlanBlockDTO) async {
        guard let token = sessionStore.session?.accessToken else { return }

        do {
            try await signalsStore.requestBreakdown(block: block, api: api, token: token)
        } catch {
            handleError(error)
        }
    }

    func createTask(title: String, dueAt: Date?, estimatedMinutes: Int?) async {
        guard let token = sessionStore.session?.accessToken else { return }
        let cleanTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard cleanTitle.isEmpty == false else { return }

        do {
            let dueString = dueAt.map { ISO8601DateFormatter().string(from: $0) }
            try await googleStore.createTask(
                title: cleanTitle,
                dueAt: dueString,
                estimatedMinutes: estimatedMinutes,
                api: api,
                token: token
            )
            try await rewardsStore.refreshWeekly(api: api, token: token)
        } catch {
            handleError(error)
        }
    }

    func saveSettings(
        coachMode: String,
        cadence: Int,
        sleepTime: String?,
        wakeTime: String?,
        sleepSuggestionsEnabled: Bool,
        pauseMonitoring: Bool,
        pushNotificationsEnabled: Bool
    ) async {
        guard let token = sessionStore.session?.accessToken else { return }

        do {
            profile = try await api.patchProfile(
                accessToken: token,
                body: PatchProfileInput(
                    coachMode: coachMode,
                    checkinCadenceMinutes: cadence,
                    sleepTime: sleepTime,
                    wakeTime: wakeTime,
                    sleepSuggestionsEnabled: sleepSuggestionsEnabled,
                    pauseMonitoring: pauseMonitoring,
                    pushNotificationsEnabled: pushNotificationsEnabled
                )
            )

            UserDefaults.standard.set(coachMode, forKey: StorageKeys.coachMode)
            UserDefaults.standard.set(cadence, forKey: StorageKeys.checkinCadence)
        } catch {
            handleError(error)
        }
    }

    func saveOnboardingIntake(
        weeklyBlocks: [OnboardingWeeklyBlockProfile],
        sleepEnergy: OnboardingSleepEnergyProfile
    ) async -> Bool {
        guard let token = sessionStore.session?.accessToken else {
            errorMessage = "Session expired. Please sign in again."
            return false
        }

        let cleanSleepTime = sleepEnergy.usualSleepTime?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanWakeTime = sleepEnergy.usualWakeTime?
            .trimmingCharacters(in: .whitespacesAndNewlines)

        let normalizedSleep = cleanSleepTime?.isEmpty == true ? nil : cleanSleepTime
        let normalizedWake = cleanWakeTime?.isEmpty == true ? nil : cleanWakeTime

        do {
            let patchedProfile = try await api.patchProfile(
                accessToken: token,
                body: PatchProfileInput(
                    sleepTime: normalizedSleep,
                    wakeTime: normalizedWake,
                    sleepSuggestionsEnabled: sleepEnergy.suggestSleepAdjustments,
                    energyProfile: mergedOnboardingEnergyProfile(
                        weeklyBlocks: weeklyBlocks,
                        sleepEnergy: OnboardingSleepEnergyProfile(
                            usualSleepTime: normalizedSleep,
                            usualWakeTime: normalizedWake,
                            typicalSleepHours: sleepEnergy.typicalSleepHours,
                            crashWindows: sleepEnergy.crashWindows,
                            suggestSleepAdjustments: sleepEnergy.suggestSleepAdjustments
                        )
                    )
                )
            )
            profile = patchedProfile
            return true
        } catch {
            handleError(error)
            return false
        }
    }

    func closeDay(biggestBlocker: String?, notes: String?, energyEnd: String) async {
        guard let token = sessionStore.session?.accessToken else { return }

        do {
            let completedOutcomes = planStore.plan?.topOutcomes ?? []
            try await insightsStore.closeDay(
                api: api,
                token: token,
                date: todayString,
                completedOutcomes: completedOutcomes,
                biggestBlocker: biggestBlocker,
                energyEnd: energyEnd,
                notes: notes
            )
            try await rewardsStore.refreshWeekly(api: api, token: token)
        } catch {
            handleError(error)
        }
    }

    func claimWeeklyReward() async {
        guard let token = sessionStore.session?.accessToken else { return }

        do {
            try await rewardsStore.claimWeekly(api: api, token: token)
            try await rewardsStore.refreshWeekly(api: api, token: token)
        } catch {
            handleError(error)
        }
    }

    func disconnectGoogle() async {
        guard let token = sessionStore.session?.accessToken else { return }

        do {
            try await api.disconnectGoogle(accessToken: token)
            integrationsStatus = nil
            googleStore.clear()
            try await loadIntegrationsStatus(token: token)
        } catch {
            handleError(error)
        }
    }

    func deleteAccount() async {
        guard let token = sessionStore.session?.accessToken else { return }

        do {
            try await api.deleteAccount(accessToken: token)
            signOut()
        } catch {
            handleError(error)
        }
    }

    func setOnboardingComplete() {
        sessionStore.markOnboardingComplete()
    }

    private func loadProfile(token: String) async throws {
        let loaded = try await api.profile(accessToken: token)
        profile = loaded
        UserDefaults.standard.set(loaded.coachMode, forKey: StorageKeys.coachMode)
        UserDefaults.standard.set(loaded.checkinCadenceMinutes, forKey: StorageKeys.checkinCadence)
    }

    private func loadIntegrationsStatus(token: String) async throws {
        integrationsStatus = try await api.integrationsStatus(accessToken: token)
    }

    private func mergedOnboardingEnergyProfile(
        weeklyBlocks: [OnboardingWeeklyBlockProfile]? = nil,
        sleepEnergy: OnboardingSleepEnergyProfile? = nil,
        dayOpen: OnboardingDayOpenProfile? = nil
    ) -> OnboardingEnergyProfile {
        let current = profile?.energyProfile

        return OnboardingEnergyProfile(
            onboardingVersion: 2,
            weeklyBlocks: weeklyBlocks ?? current?.weeklyBlocks,
            sleepEnergy: sleepEnergy ?? current?.sleepEnergy,
            dayOpen: dayOpen ?? current?.dayOpen
        )
    }

    private func clearStores() {
        profile = nil
        integrationsStatus = nil
        planStore.clear()
        googleStore.clear()
        signalsStore.clear()
        insightsStore.clear()
        rewardsStore.clear()
        router.selectedTab = .dashboard
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
}
