import SwiftUI

struct MainTabView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        TabView(selection: $appState.router.selectedTab) {
            NavigationStack {
                DashboardRootView()
            }
            .tabItem {
                Label(OmniTab.dashboard.title, systemImage: OmniTab.dashboard.icon)
            }
            .tag(OmniTab.dashboard)

            NavigationStack {
                CalendarRootView()
            }
            .tabItem {
                Label(OmniTab.calendar.title, systemImage: OmniTab.calendar.icon)
            }
            .tag(OmniTab.calendar)

            NavigationStack {
                FeedbackRootView()
            }
            .tabItem {
                Label(OmniTab.feedback.title, systemImage: OmniTab.feedback.icon)
            }
            .tag(OmniTab.feedback)

            NavigationStack {
                RewardRootView()
            }
            .tabItem {
                Label(OmniTab.reward.title, systemImage: OmniTab.reward.icon)
            }
            .tag(OmniTab.reward)

            NavigationStack {
                SettingsRootView()
            }
            .tabItem {
                Label(OmniTab.settings.title, systemImage: OmniTab.settings.icon)
            }
            .tag(OmniTab.settings)
        }
        .tint(Color.omniAccent)
        .task {
            await appState.refreshIfAuthenticated(fullRefresh: false)
        }
    }
}

struct DashboardRootView: View {
    @EnvironmentObject var appState: AppState

    @State private var showCheckin = false
    @State private var driftReason = ""

    private var currentBlock: PlanBlockDTO? {
        appState.planStore.currentBlock()
    }

    private var nextTask: PlanBlockDTO? {
        appState.planStore.nextTaskBlock()
    }

    private var nextEvent: CalendarEventDTO? {
        appState.googleStore.nextUpcomingEvent(on: appState.todayString)
    }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color.omniBackground, Color.omniCard],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    headerCard

                    if let currentBlock {
                        taskInProgressCard(currentBlock)

                        Button {
                            Task { await appState.startFocusSession(block: currentBlock) }
                        } label: {
                            HStack {
                                Image(systemName: "play.fill")
                                Text("Start Focus Session")
                                    .fontWeight(.semibold)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(Color.omniAccent)

                        actionRow(currentBlock)
                    } else {
                        emptyCurrentBlockCard
                    }

                    if let nextTask {
                        upcomingTaskCard(nextTask)
                    }

                    if let nextEvent {
                        upcomingEventCard(nextEvent)
                    }

                    if let nudge = appState.signalsStore.latestNudge {
                        nudgeCard(nudge)
                    }

                    if let breakdown = appState.signalsStore.latestBreakdown {
                        breakdownCard(breakdown)
                    }
                }
                .padding(20)
            }
        }
        .navigationTitle("Dashboard")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showCheckin) {
            if let currentBlock {
                MicroCheckinSheet(
                    block: currentBlock,
                    initialEnergy: appState.profile?.energyProfile?.dayOpen?.lastEnergy
                ) { payload in
                    Task {
                        await appState.submitCheckin(
                            block: currentBlock,
                            done: payload.done,
                            progress: payload.progress,
                            focus: payload.focus,
                            energy: payload.energy,
                            happenedTags: payload.happenedTags,
                            derailReason: payload.derailReason,
                            driftMinutes: payload.driftMinutes
                        )
                    }
                }
            }
        }
        .refreshable {
            await appState.refreshIfAuthenticated(fullRefresh: false)
        }
    }

    private var headerCard: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(appState.displayName)
                .font(.system(size: 40, weight: .bold))
                .foregroundStyle(.white)
            Text("Your Day, Optimized.")
                .font(.title3)
                .foregroundStyle(Color.omniMuted)
        }
    }

    private func taskInProgressCard(_ block: PlanBlockDTO) -> some View {
        let progressPercent = progressPercent(for: block)

        return HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Task in Progress")
                    .font(.headline)
                    .foregroundStyle(Color.omniMuted)
                Text(block.label)
                    .font(.system(size: 34, weight: .bold))
                    .foregroundStyle(.white)
                    .lineLimit(3)
                Text(block.rationale)
                    .font(.footnote)
                    .foregroundStyle(Color.omniMuted)
                    .lineLimit(1)
            }

            Spacer(minLength: 12)

            ProgressRingView(progress: Double(progressPercent) / 100.0)
                .frame(width: 76, height: 76)
                .overlay {
                    Text("\(progressPercent)%")
                        .font(.headline)
                        .foregroundStyle(.white)
                }
        }
        .padding(18)
        .background(Color.black.opacity(0.55))
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }

    private func actionRow(_ block: PlanBlockDTO) -> some View {
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                Button("✅ Done") {
                    Task { await appState.completeCurrentBlock(block) }
                }
                .buttonStyle(.bordered)

                Button("🟡 Not Done") {
                    showCheckin = true
                }
                .buttonStyle(.bordered)
            }

            HStack(spacing: 10) {
                Button("🔥 I'm drifting") {
                    Task { await appState.submitDrift(block: block, derailReason: driftReason.isEmpty ? nil : driftReason) }
                }
                .buttonStyle(.bordered)

                Button("🔄 Swap") {
                    Task { await appState.requestSwap(block: block) }
                }
                .buttonStyle(.bordered)

                Button("🧩 Breakdown") {
                    Task { await appState.requestBreakdown(block: block) }
                }
                .buttonStyle(.bordered)
            }

            TextField("Optional drift reason", text: $driftReason)
                .textFieldStyle(.roundedBorder)
                .font(.footnote)
        }
    }

    private var emptyCurrentBlockCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Task in Progress")
                .font(.headline)
                .foregroundStyle(Color.omniMuted)
            Text("No active block")
                .font(.title3.bold())
                .foregroundStyle(.white)
            Text("Generate a plan or open Calendar to view upcoming blocks.")
                .foregroundStyle(Color.omniMuted)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.black.opacity(0.55))
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }

    private func upcomingTaskCard(_ block: PlanBlockDTO) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Upcoming Task")
                    .font(.headline)
                    .foregroundStyle(Color.omniMuted)
                Spacer()
                Button("SWAP") {
                    Task { await appState.requestSwap(block: block) }
                }
                .buttonStyle(.bordered)
            }

            Text(block.label)
                .font(.title2.bold())
                .foregroundStyle(.white)
            Text("Scheduled for \(block.startDate?.formatted(date: .omitted, time: .shortened) ?? "-")")
                .foregroundStyle(Color.omniMuted)
                .font(.subheadline)
        }
        .padding(18)
        .background(Color.black.opacity(0.55))
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }

    private func upcomingEventCard(_ event: CalendarEventDTO) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Upcoming Social Event")
                .font(.headline)
                .foregroundStyle(Color.omniMuted)

            Text(event.title)
                .font(.title2.bold())
                .foregroundStyle(.white)

            Text(event.startDate?.formatted(date: .omitted, time: .shortened) ?? "")
                .foregroundStyle(Color.omniMuted)

            Text("social event")
                .font(.caption)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.omniAccent.opacity(0.2))
                .foregroundStyle(Color.omniAccent)
                .clipShape(Capsule())
        }
        .padding(18)
        .background(Color.black.opacity(0.55))
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }

    private func nudgeCard(_ nudge: NudgeDTO) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("AI Nudge: \(nudge.recommendedAction.capitalized)")
                .font(.headline)
                .foregroundStyle(.white)
            Text(nudge.rationale)
                .foregroundStyle(Color.omniMuted)
            ForEach(nudge.alternatives, id: \.self) { alternative in
                Text("• \(alternative)")
                    .font(.footnote)
                    .foregroundStyle(Color.omniMuted)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.black.opacity(0.45))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private func breakdownCard(_ breakdown: BreakdownDTO) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Subtasks")
                .font(.headline)
                .foregroundStyle(.white)
            ForEach(breakdown.subtasks, id: \.self) { subtask in
                Text("\(subtask.order + 1). \(subtask.title) (\(subtask.estimatedMinutes)m)")
                    .font(.footnote)
                    .foregroundStyle(Color.omniMuted)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.black.opacity(0.45))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private func progressPercent(for block: PlanBlockDTO) -> Int {
        if let explicit = appState.planStore.progress(for: block) {
            return Int(explicit.rounded())
        }

        if let focus = appState.signalsStore.activeFocusSession,
           block.id == focus.blockId
        {
            return Int((focus.progress * 100).rounded())
        }

        guard
            let start = block.startDate,
            let end = block.endDate,
            end > start,
            Date() >= start
        else {
            return 0
        }

        let ratio = min(1, Date().timeIntervalSince(start) / end.timeIntervalSince(start))
        return Int((ratio * 100).rounded())
    }
}

struct CalendarRootView: View {
    @EnvironmentObject var appState: AppState

    @State private var selectedDate = Date()
    @State private var selectedTimelineItem: CalendarTimelineItem?
    @State private var showAddTask = false

    private var dateString: String {
        OmniDateParser.dayString(selectedDate)
    }

    private var timelineItems: [CalendarTimelineItem] {
        appState.planStore.timelineItems(
            for: dateString,
            events: appState.googleStore.events(for: dateString)
        )
    }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color.omniBackground, Color.omniCard],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 14) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Calendar")
                        .font(.system(size: 44, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    Text(selectedDate.formatted(date: .complete, time: .omitted))
                        .foregroundStyle(Color.omniMuted)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    DatePicker("", selection: $selectedDate, displayedComponents: .date)
                        .labelsHidden()
                        .datePickerStyle(.compact)
                        .tint(Color.omniAccent)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(.horizontal, 20)

                DayTimelineView(items: timelineItems) { tappedItem in
                    selectedTimelineItem = tappedItem
                }
                .frame(maxWidth: .infinity)

                Button {
                    showAddTask = true
                } label: {
                    Label("+ Add Task", systemImage: "plus")
                        .font(.title3.bold())
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                }
                .buttonStyle(.borderedProminent)
                .tint(Color.omniAccent)
                .padding(.horizontal, 20)
                .padding(.bottom, 10)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await appState.refreshCalendar(date: selectedDate)
        }
        .onChange(of: selectedDate) { _ in
            Task {
                await appState.refreshCalendar(date: selectedDate)
            }
        }
        .sheet(item: $selectedTimelineItem) { item in
            if item.source == .calendar, let event = item.event {
                EventDetailSheet(event: event)
            } else if let block = item.planBlock {
                BlockDetailSheet(block: block)
                    .environmentObject(appState)
            }
        }
        .sheet(isPresented: $showAddTask) {
            CreateTaskSheet { title, dueDate, estimate in
                Task {
                    await appState.createTask(title: title, dueAt: dueDate, estimatedMinutes: estimate)
                }
            }
        }
        .refreshable {
            await appState.refreshCalendar(date: selectedDate)
        }
    }
}

struct FeedbackRootView: View {
    @EnvironmentObject var appState: AppState

    private var insights: InsightsTodayDTO {
        appState.insightsStore.today ?? InsightsTodayDTO(
            driftMinutesToday: 0,
            bestFocusWindow: "10 AM - 12 PM",
            mostProductiveTimeLabel: "Morning",
            mostProductiveTimeRange: "8 AM - 12 PM",
            mostCommonDerailLabel: "Social Media",
            mostCommonDerailAvgMinutes: 15,
            burnoutRiskLevel: "low",
            burnoutExplanation: "Your current workload is manageable.",
            learnedBullets: ["Keep protecting your first focus block"]
        )
    }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color.omniBackground, Color.omniCard],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Feedback")
                        .font(.system(size: 44, weight: .bold))
                        .foregroundStyle(.white)

                    VStack(alignment: .leading, spacing: 12) {
                        Text("Focus & Drift Summary")
                            .font(.title2.bold())
                            .foregroundStyle(.white)

                        Text("Drift minutes today")
                            .foregroundStyle(Color.omniMuted)

                        HStack(alignment: .bottom) {
                            Text("\(insights.driftMinutesToday) min")
                                .font(.system(size: 48, weight: .bold))
                                .foregroundStyle(Color.omniAccent)

                            Spacer()

                            HStack(alignment: .bottom, spacing: 6) {
                                ForEach([8, 12, 10, 16, 11, 9], id: \.self) { value in
                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(Color.omniAccent.opacity(0.35))
                                        .frame(width: 20, height: CGFloat(value) * 2)
                                }
                            }
                        }

                        Text("Best focus window: \(insights.bestFocusWindow)")
                            .font(.headline)
                            .foregroundStyle(Color.omniAccent)
                            .padding(.vertical, 10)
                            .padding(.horizontal, 14)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.omniAccent.opacity(0.15))
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                    .padding(18)
                    .background(Color.black.opacity(0.55))
                    .clipShape(RoundedRectangle(cornerRadius: 20))

                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Most productive time")
                                .foregroundStyle(Color.omniMuted)
                            Text(insights.mostProductiveTimeLabel)
                                .font(.title2.bold())
                                .foregroundStyle(.white)
                            Text(insights.mostProductiveTimeRange)
                                .foregroundStyle(Color.omniMuted)
                        }
                        .padding(16)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.black.opacity(0.55))
                        .clipShape(RoundedRectangle(cornerRadius: 18))

                        VStack(alignment: .leading, spacing: 8) {
                            Text("Most common derail")
                                .foregroundStyle(Color.omniMuted)
                            Text(insights.mostCommonDerailLabel)
                                .font(.title2.bold())
                                .foregroundStyle(.white)
                            Text("\(insights.mostCommonDerailAvgMinutes) min avg")
                                .foregroundStyle(Color.omniMuted)
                        }
                        .padding(16)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.black.opacity(0.55))
                        .clipShape(RoundedRectangle(cornerRadius: 18))
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("Burnout Guardrail")
                                .font(.title2.bold())
                                .foregroundStyle(.white)
                            Spacer()
                            Text(insights.burnoutRiskLevel.capitalized)
                                .foregroundStyle(Color.omniAccent)
                                .font(.title3.bold())
                        }

                        let levelValue = burnoutLevelValue(insights.burnoutRiskLevel)
                        GeometryReader { proxy in
                            ZStack(alignment: .leading) {
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(Color.white.opacity(0.15))
                                    .frame(height: 12)
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(Color.omniAccent)
                                    .frame(width: proxy.size.width * levelValue, height: 12)
                            }
                        }
                        .frame(height: 12)

                        Text(insights.burnoutExplanation)
                            .foregroundStyle(Color.omniMuted)
                    }
                    .padding(18)
                    .background(Color.black.opacity(0.55))
                    .clipShape(RoundedRectangle(cornerRadius: 20))

                    VStack(alignment: .leading, spacing: 8) {
                        Text("What Omni learned about you")
                            .font(.title2.bold())
                            .foregroundStyle(.white)

                        ForEach(insights.learnedBullets, id: \.self) { bullet in
                            HStack(alignment: .top, spacing: 10) {
                                Circle()
                                    .fill(Color.omniAccent)
                                    .frame(width: 8, height: 8)
                                    .padding(.top, 8)
                                Text(bullet)
                                    .foregroundStyle(Color.omniMuted)
                            }
                        }
                    }
                    .padding(18)
                    .background(Color.black.opacity(0.55))
                    .clipShape(RoundedRectangle(cornerRadius: 20))
                }
                .padding(20)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await appState.refreshIfAuthenticated(fullRefresh: false)
        }
        .refreshable {
            await appState.refreshIfAuthenticated(fullRefresh: false)
        }
    }

    private func burnoutLevelValue(_ level: String) -> Double {
        switch level.lowercased() {
        case "high": return 0.9
        case "med": return 0.6
        default: return 0.35
        }
    }
}

struct RewardRootView: View {
    @EnvironmentObject var appState: AppState

    @State private var showClaimMessage = false

    private var rewards: RewardsWeeklyDTO {
        appState.rewardsStore.weekly ?? RewardsWeeklyDTO(
            omniScore: 0,
            encouragement: "Keep going.",
            daysCompletedThisWeek: 0,
            dayStates: [false, false, false, false, false, false, false],
            badges: []
        )
    }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color.omniBackground, Color.omniCard],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Reward")
                        .font(.system(size: 44, weight: .bold))
                        .foregroundStyle(.white)

                    VStack(spacing: 12) {
                        Text("YOUR OMNI SCORE")
                            .font(.headline)
                            .foregroundStyle(Color.omniMuted)

                        ProgressRingView(progress: Double(rewards.omniScore) / 100.0)
                            .frame(width: 210, height: 210)
                            .overlay {
                                VStack(spacing: 4) {
                                    Text("\(rewards.omniScore)")
                                        .font(.system(size: 56, weight: .bold))
                                        .foregroundStyle(.white)
                                    Text("/ 100")
                                        .foregroundStyle(Color.omniMuted)
                                }
                            }

                        Text(rewards.encouragement)
                            .foregroundStyle(Color.omniMuted)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(18)
                    .background(Color.black.opacity(0.55))
                    .clipShape(RoundedRectangle(cornerRadius: 20))

                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("Weekly Consistency")
                                .font(.title2.bold())
                                .foregroundStyle(.white)
                            Spacer()
                            Text("\(rewards.daysCompletedThisWeek)/7")
                                .font(.title.bold())
                                .foregroundStyle(Color.omniAccent)
                        }

                        HStack(spacing: 12) {
                            ForEach(Array(["M", "T", "W", "T", "F", "S", "S"].enumerated()), id: \.offset) { index, day in
                                VStack(spacing: 8) {
                                    Text(day)
                                        .foregroundStyle(Color.omniMuted)
                                    Circle()
                                        .fill(rewards.dayStates[safe: index] == true ? Color.omniAccent : Color.white.opacity(0.12))
                                        .frame(width: 28, height: 28)
                                }
                                .frame(maxWidth: .infinity)
                            }
                        }
                    }
                    .padding(18)
                    .background(Color.black.opacity(0.55))
                    .clipShape(RoundedRectangle(cornerRadius: 20))

                    VStack(alignment: .leading, spacing: 12) {
                        Text("Badges")
                            .font(.title2.bold())
                            .foregroundStyle(.white)

                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                            ForEach(rewards.badges) { badge in
                                VStack(spacing: 8) {
                                    Circle()
                                        .fill(badge.unlocked ? Color.omniAccent : Color.white.opacity(0.08))
                                        .frame(width: 74, height: 74)
                                        .overlay {
                                            Image(systemName: badge.unlocked ? "trophy" : "lock")
                                                .foregroundStyle(badge.unlocked ? .black : Color.omniMuted)
                                        }
                                    Text(badge.title)
                                        .font(.footnote)
                                        .multilineTextAlignment(.center)
                                        .foregroundStyle(badge.unlocked ? .white : Color.omniMuted)
                                }
                            }
                        }
                    }
                    .padding(18)
                    .background(Color.black.opacity(0.55))
                    .clipShape(RoundedRectangle(cornerRadius: 20))

                    Button("Claim Weekly Reward") {
                        Task {
                            await appState.claimWeeklyReward()
                            showClaimMessage = true
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Color.omniAccent)
                    .frame(maxWidth: .infinity)
                }
                .padding(20)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .alert("Reward", isPresented: $showClaimMessage) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(appState.rewardsStore.claimMessage ?? "Weekly reward claimed")
        }
        .task {
            await appState.refreshIfAuthenticated(fullRefresh: false)
        }
        .refreshable {
            await appState.refreshIfAuthenticated(fullRefresh: false)
        }
    }
}

struct SettingsRootView: View {
    @EnvironmentObject var appState: AppState

    @State private var coachMode = "balanced"
    @State private var cadence = 60
    @State private var sleepBaselineStart = "11:00 PM"
    @State private var sleepBaselineEnd = "7:00 AM"
    @State private var sleepSuggestions = true
    @State private var pauseMonitoring = false
    @State private var pushNotifications = true

    @State private var showDeleteConfirm = false
    @State private var showDisclosure = false

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color.omniBackground, Color.omniCard],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Settings")
                        .font(.system(size: 44, weight: .bold))
                        .foregroundStyle(.white)

                    profileCard
                    integrationsCard
                    sleepRecoveryCard
                    privacyCard
                    notificationsCard
                }
                .padding(20)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await appState.refreshIfAuthenticated(fullRefresh: false)
            hydrateFromProfile()
        }
        .confirmationDialog("Delete account?", isPresented: $showDeleteConfirm, titleVisibility: .visible) {
            Button("Delete", role: .destructive) {
                Task { await appState.deleteAccount() }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This removes your Omni account and associated data.")
        }
        .sheet(isPresented: $showDisclosure) {
            NavigationStack {
                ScrollView {
                    Text("Omni monitors your planned blocks, check-ins, manual drift reports, and completion events. It does not use Screen Time entitlements in this build.")
                        .padding()
                }
                .navigationTitle("What Omni Monitors")
                .navigationBarTitleDisplayMode(.inline)
            }
        }
        .refreshable {
            await appState.refreshIfAuthenticated(fullRefresh: false)
            hydrateFromProfile()
        }
    }

    private var profileCard: some View {
        HStack(spacing: 14) {
            Circle()
                .fill(Color.omniAccent)
                .frame(width: 58, height: 58)
                .overlay {
                    Text("OU")
                        .font(.headline)
                        .foregroundStyle(.black)
                }

            VStack(alignment: .leading, spacing: 4) {
                Text(appState.displayName)
                    .font(.title3.bold())
                    .foregroundStyle(.white)
                Text("Student Focus Profile")
                    .foregroundStyle(Color.omniMuted)
            }
            Spacer()
        }
        .padding(16)
        .background(Color.black.opacity(0.55))
        .clipShape(RoundedRectangle(cornerRadius: 18))
    }

    private var integrationsCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Integrations")
                .font(.title2.bold())
                .foregroundStyle(.white)

            integrationRow(
                title: "Google Calendar",
                connected: appState.integrationsStatus?.googleCalendarConnected ?? false
            )
            integrationRow(
                title: "Google Tasks",
                connected: appState.integrationsStatus?.googleTasksConnected ?? false
            )

            HStack {
                Text("Drift Tracking")
                    .foregroundStyle(.white)
                Spacer()
                Text("Manual")
                    .foregroundStyle(Color.omniAccent)
                Image(systemName: "checkmark")
                    .foregroundStyle(Color.omniAccent)
            }
            .padding(12)
            .background(Color.white.opacity(0.05))
            .clipShape(RoundedRectangle(cornerRadius: 12))

            Text(appState.integrationsStatus?.explanation ?? "Omni adapts via check-ins + 'I'm drifting'.")
                .font(.footnote)
                .foregroundStyle(Color.omniMuted)
        }
        .padding(16)
        .background(Color.black.opacity(0.55))
        .clipShape(RoundedRectangle(cornerRadius: 18))
    }

    private var sleepRecoveryCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Sleep & Recovery")
                .font(.title2.bold())
                .foregroundStyle(.white)

            TextField("Sleep baseline start", text: $sleepBaselineStart)
                .textFieldStyle(.roundedBorder)
            TextField("Sleep baseline end", text: $sleepBaselineEnd)
                .textFieldStyle(.roundedBorder)

            Toggle("Sleep suggestions", isOn: $sleepSuggestions)
                .tint(Color.omniAccent)
                .foregroundStyle(.white)
                .onChange(of: sleepSuggestions) { _ in
                    persistSettings()
                }
        }
        .padding(16)
        .background(Color.black.opacity(0.55))
        .clipShape(RoundedRectangle(cornerRadius: 18))
    }

    private var privacyCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Privacy")
                .font(.title2.bold())
                .foregroundStyle(.white)

            Toggle("Pause monitoring", isOn: $pauseMonitoring)
                .tint(Color.omniAccent)
                .foregroundStyle(.white)
                .onChange(of: pauseMonitoring) { _ in
                    persistSettings()
                }

            Button("What Omni monitors") {
                showDisclosure = true
            }
            .buttonStyle(.bordered)
        }
        .padding(16)
        .background(Color.black.opacity(0.55))
        .clipShape(RoundedRectangle(cornerRadius: 18))
    }

    private var notificationsCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Notifications & Account")
                .font(.title2.bold())
                .foregroundStyle(.white)

            Toggle("Push notifications", isOn: $pushNotifications)
                .tint(Color.omniAccent)
                .foregroundStyle(.white)
                .onChange(of: pushNotifications) { _ in
                    persistSettings()
                }

            Picker("Coach Mode", selection: $coachMode) {
                Text("Gentle").tag("gentle")
                Text("Balanced").tag("balanced")
                Text("Strict").tag("strict")
            }
            .pickerStyle(.segmented)
            .onChange(of: coachMode) { _ in
                persistSettings()
            }

            Stepper("Check-in cadence: \(cadence) min", value: $cadence, in: 15...180, step: 15)
                .foregroundStyle(.white)
                .onChange(of: cadence) { _ in
                    persistSettings()
                }

            Button("Disconnect Google") {
                Task { await appState.disconnectGoogle() }
            }
            .buttonStyle(.bordered)

            Button("Sign out") {
                appState.signOut()
            }
            .foregroundStyle(.red)

            Button("Delete account") {
                showDeleteConfirm = true
            }
            .foregroundStyle(.red)
        }
        .padding(16)
        .background(Color.black.opacity(0.55))
        .clipShape(RoundedRectangle(cornerRadius: 18))
    }

    private func integrationRow(title: String, connected: Bool) -> some View {
        HStack {
            Text(title)
                .foregroundStyle(.white)
            Spacer()
            Text(connected ? "Connected" : "Not connected")
                .foregroundStyle(connected ? Color.omniAccent : Color.omniMuted)
            if connected {
                Image(systemName: "checkmark")
                    .foregroundStyle(Color.omniAccent)
            }
        }
        .padding(12)
        .background(Color.white.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func hydrateFromProfile() {
        guard let profile = appState.profile else { return }

        coachMode = profile.coachMode
        cadence = max(15, profile.checkinCadenceMinutes)
        sleepBaselineStart = profile.sleepTime ?? "11:00 PM"
        sleepBaselineEnd = profile.wakeTime ?? "7:00 AM"
        sleepSuggestions = profile.sleepSuggestionsEnabled ?? true
        pauseMonitoring = profile.pauseMonitoring ?? false
        pushNotifications = profile.pushNotificationsEnabled ?? true
    }

    private func persistSettings() {
        Task {
            await appState.saveSettings(
                coachMode: coachMode,
                cadence: cadence,
                sleepTime: sleepBaselineStart,
                wakeTime: sleepBaselineEnd,
                sleepSuggestionsEnabled: sleepSuggestions,
                pauseMonitoring: pauseMonitoring,
                pushNotificationsEnabled: pushNotifications
            )
        }
    }
}

private struct DayTimelineView: View {
    let items: [CalendarTimelineItem]
    let onTapItem: (CalendarTimelineItem) -> Void

    private let startHour = 8
    private let endHour = 21
    private let rowHeight: CGFloat = 86

    var body: some View {
        ScrollView {
            HStack(alignment: .top, spacing: 10) {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(startHour...endHour, id: \.self) { hour in
                        Text(label(for: hour))
                            .foregroundStyle(Color.omniMuted)
                            .frame(height: rowHeight, alignment: .topLeading)
                    }
                }
                .frame(width: 90)

                GeometryReader { proxy in
                    ZStack(alignment: .topLeading) {
                        VStack(spacing: 0) {
                            ForEach(startHour...endHour, id: \.self) { _ in
                                Rectangle()
                                    .fill(Color.white.opacity(0.08))
                                    .frame(height: 1)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(.top, rowHeight - 1)
                            }
                        }

                        ForEach(items) { item in
                            Button {
                                onTapItem(item)
                            } label: {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(item.title)
                                        .font(.headline)
                                        .foregroundStyle(item.source == .plan ? Color.omniAccent : .white)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                    if let subtitle = item.subtitle, subtitle.isEmpty == false {
                                        Text(subtitle)
                                            .font(.subheadline)
                                            .foregroundStyle(Color.omniMuted)
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                    }
                                }
                                .padding(12)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(item.source == .plan ? Color.omniAccent.opacity(0.12) : Color.black.opacity(0.65))
                                .overlay {
                                    RoundedRectangle(cornerRadius: 14)
                                        .stroke(item.source == .plan ? Color.omniAccent : Color.purple.opacity(0.8), lineWidth: 1)
                                }
                                .clipShape(RoundedRectangle(cornerRadius: 14))
                            }
                            .buttonStyle(.plain)
                            .frame(width: proxy.size.width - 8)
                            .position(
                                x: (proxy.size.width - 8) / 2,
                                y: yOffset(for: item) + itemHeight(for: item) / 2
                            )
                            .frame(height: itemHeight(for: item))
                        }
                    }
                }
                .frame(height: CGFloat(endHour - startHour + 1) * rowHeight)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 10)
        }
    }

    private func label(for hour: Int) -> String {
        let display = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour)
        let suffix = hour >= 12 ? "PM" : "AM"
        return "\(display):00 \(suffix)"
    }

    private func yOffset(for item: CalendarTimelineItem) -> CGFloat {
        let calendar = Calendar.current
        let startMinutes = startHour * 60
        let itemMinutes = (calendar.component(.hour, from: item.start) * 60) + calendar.component(.minute, from: item.start)
        let delta = max(0, itemMinutes - startMinutes)
        return CGFloat(delta) * (rowHeight / 60)
    }

    private func itemHeight(for item: CalendarTimelineItem) -> CGFloat {
        let durationMinutes = max(30, Int(item.end.timeIntervalSince(item.start) / 60))
        return CGFloat(durationMinutes) * (rowHeight / 60)
    }
}

private struct EventDetailSheet: View {
    let event: CalendarEventDTO

    var body: some View {
        NavigationStack {
            List {
                Section("Event") {
                    Text(event.title)
                    Text(event.startDate?.formatted(date: .omitted, time: .shortened) ?? "")
                    Text(event.endDate?.formatted(date: .omitted, time: .shortened) ?? "")
                    if let location = event.location {
                        Text(location)
                    }
                }
            }
            .navigationTitle("Calendar Event")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

private struct BlockDetailSheet: View {
    @EnvironmentObject var appState: AppState
    let block: PlanBlockDTO

    @State private var showCheckin = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    Text(block.label)
                        .font(.title2.bold())
                    Text(block.rationale)
                        .foregroundStyle(.secondary)

                    Button("✅ Done") {
                        Task { await appState.completeCurrentBlock(block) }
                    }
                    .buttonStyle(.borderedProminent)

                    Button("🟡 Not Done") {
                        showCheckin = true
                    }
                    .buttonStyle(.bordered)

                    Button("🔥 I'm drifting") {
                        Task { await appState.submitDrift(block: block, derailReason: nil) }
                    }
                    .buttonStyle(.bordered)

                    Button("🔄 Swap") {
                        Task { await appState.requestSwap(block: block) }
                    }
                    .buttonStyle(.bordered)

                    Button("🧩 Break into steps") {
                        Task { await appState.requestBreakdown(block: block) }
                    }
                    .buttonStyle(.bordered)
                }
                .padding()
            }
            .navigationTitle("Plan Block")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showCheckin) {
                MicroCheckinSheet(
                    block: block,
                    initialEnergy: appState.profile?.energyProfile?.dayOpen?.lastEnergy
                ) { payload in
                    Task {
                        await appState.submitCheckin(
                            block: block,
                            done: payload.done,
                            progress: payload.progress,
                            focus: payload.focus,
                            energy: payload.energy,
                            happenedTags: payload.happenedTags,
                            derailReason: payload.derailReason,
                            driftMinutes: payload.driftMinutes
                        )
                    }
                }
            }
        }
    }
}

private struct CreateTaskSheet: View {
    @Environment(\.dismiss) private var dismiss

    @State private var title = ""
    @State private var hasDueDate = false
    @State private var dueDate = Date()
    @State private var estimate = 0

    let onCreate: (String, Date?, Int?) -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section("Task") {
                    TextField("Title", text: $title)
                    Toggle("Due date", isOn: $hasDueDate)
                    if hasDueDate {
                        DatePicker("Due", selection: $dueDate, displayedComponents: [.date, .hourAndMinute])
                    }
                    Stepper("Estimate: \(estimate) min", value: $estimate, in: 0...240, step: 5)
                }
            }
            .navigationTitle("Add Task")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Create") {
                        onCreate(title, hasDueDate ? dueDate : nil, estimate > 0 ? estimate : nil)
                        dismiss()
                    }
                    .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
}

private struct ProgressRingView: View {
    let progress: Double

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.white.opacity(0.18), lineWidth: 8)
            Circle()
                .trim(from: 0, to: max(0.02, min(1, progress)))
                .stroke(Color.omniAccent, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                .rotationEffect(.degrees(-90))
        }
    }
}

private struct MicroCheckinPayload {
    let done: Bool
    let progress: Double
    let focus: Double
    let energy: String?
    let happenedTags: [String]
    let derailReason: String?
    let driftMinutes: Int?
}

private struct MicroCheckinSheet: View {
    @Environment(\.dismiss) private var dismiss

    let block: PlanBlockDTO
    let initialEnergy: String?
    let onSubmit: (MicroCheckinPayload) -> Void

    @State private var done = false
    @State private var progress = 50.0
    @State private var focus = 7.0
    @State private var energy: String = ""
    @State private var selectedTags: Set<String> = []
    @State private var otherReason = ""
    @State private var driftMinutes = 0

    private let tags = ["distracted", "stuck", "tired", "unclear", "pulled away", "other"]

    init(
        block: PlanBlockDTO,
        initialEnergy: String? = nil,
        onSubmit: @escaping (MicroCheckinPayload) -> Void
    ) {
        self.block = block
        self.initialEnergy = initialEnergy
        self.onSubmit = onSubmit
        let normalized = ["low", "med", "high"].contains(initialEnergy ?? "") ? (initialEnergy ?? "") : ""
        _energy = State(initialValue: normalized)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Block") {
                    Text(block.label)
                }

                Section("Done?") {
                    Picker("Done?", selection: $done) {
                        Text("No").tag(false)
                        Text("Yes").tag(true)
                    }
                    .pickerStyle(.segmented)
                }

                if done == false {
                    Section("Progress") {
                        HStack {
                            Text("\(Int(progress))%")
                            Slider(value: $progress, in: 0...100)
                        }
                    }

                    Section("Focus") {
                        HStack {
                            Text("\(Int(focus))/10")
                            Slider(value: $focus, in: 1...10, step: 1)
                        }
                    }

                    Section("Energy (optional)") {
                        Picker("Energy", selection: $energy) {
                            Text("None").tag("")
                            Text("Low").tag("low")
                            Text("Med").tag("med")
                            Text("High").tag("high")
                        }
                        .pickerStyle(.segmented)
                    }

                    Section("What happened?") {
                        FlexibleTagGrid(tags: tags, selectedTags: $selectedTags)
                        if selectedTags.contains("other") {
                            TextField("Other", text: $otherReason)
                        }
                    }

                    Section("Drift minutes (optional)") {
                        Stepper("\(driftMinutes) min", value: $driftMinutes, in: 0...30)
                    }
                }
            }
            .navigationTitle("Micro Check-in")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Submit") {
                        let derailReason = selectedTags.contains("other") ? otherReason : nil
                        onSubmit(
                            MicroCheckinPayload(
                                done: done,
                                progress: done ? 100 : progress,
                                focus: done ? 8 : focus,
                                energy: energy.isEmpty ? nil : energy,
                                happenedTags: Array(selectedTags),
                                derailReason: derailReason,
                                driftMinutes: driftMinutes > 0 ? driftMinutes : nil
                            )
                        )
                        dismiss()
                    }
                }
            }
        }
    }
}

private struct FlexibleTagGrid: View {
    let tags: [String]
    @Binding var selectedTags: Set<String>

    private let columns = [GridItem(.adaptive(minimum: 90), spacing: 8)]

    var body: some View {
        LazyVGrid(columns: columns, alignment: .leading, spacing: 8) {
            ForEach(tags, id: \.self) { tag in
                Button {
                    if selectedTags.contains(tag) {
                        selectedTags.remove(tag)
                    } else {
                        selectedTags.insert(tag)
                    }
                } label: {
                    Text(tag)
                        .font(.footnote)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .frame(maxWidth: .infinity)
                        .background(selectedTags.contains(tag) ? Color.omniAccent.opacity(0.25) : Color.gray.opacity(0.2))
                        .foregroundStyle(selectedTags.contains(tag) ? Color.omniAccent : .primary)
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        }
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
