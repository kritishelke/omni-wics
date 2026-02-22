import SwiftUI
import FamilyControls

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
