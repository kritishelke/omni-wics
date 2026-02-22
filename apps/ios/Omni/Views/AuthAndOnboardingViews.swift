import SwiftUI

struct AuthView: View {
    @EnvironmentObject var appState: AppState

    @State private var email = ""
    @State private var password = ""
    @State private var isSubmitting = false

    var body: some View {
        ZStack {
            OmniNebulaBackground()

            VStack(spacing: 24) {
                Image("AppLogo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 92, height: 92)
                    .clipShape(RoundedRectangle(cornerRadius: 18))
                    .overlay(
                        RoundedRectangle(cornerRadius: 18)
                            .stroke(Color.omniAccent.opacity(0.45), lineWidth: 1)
                    )

                Text("Omni")
                    .font(.omniScript(size: 56))
                    .foregroundStyle(Color.omniGlow)
                    .shadow(color: Color.omniGlow.opacity(0.7), radius: 10)

                Text("Sign in to start your day plan")
                    .foregroundStyle(Color.omniMuted)

                VStack(spacing: 10) {
                    TextField("Email", text: $email)
                        .textInputAutocapitalization(.never)
                        .keyboardType(.emailAddress)
                        .autocorrectionDisabled()
                        .padding(12)
                        .background(Color.white.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 10))

                    SecureField("Password", text: $password)
                        .padding(12)
                        .background(Color.white.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                .foregroundStyle(.white)

                Button {
                    submit(signup: false)
                } label: {
                    Text("Sign In")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(Color.omniAccent)
                .disabled(isSubmitting)

                Button {
                    submit(signup: true)
                } label: {
                    Text("Create Account")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .disabled(isSubmitting)
            }
            .padding(24)
        }
    }

    private func submit(signup: Bool) {
        let cleanEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanPassword = password.trimmingCharacters(in: .whitespacesAndNewlines)

        guard cleanEmail.isEmpty == false, cleanPassword.isEmpty == false else {
            appState.errorMessage = "Email and password are required."
            return
        }

        isSubmitting = true
        Task {
            if signup {
                await appState.signUpWithEmail(email: cleanEmail, password: cleanPassword)
            } else {
                await appState.signInWithEmail(email: cleanEmail, password: cleanPassword)
            }
            isSubmitting = false
        }
    }
}

struct OnboardingFlowView: View {
    @EnvironmentObject var appState: AppState

    @State private var step = 0
    @State private var selectedBlocks: Set<String> = []
    @State private var hardBlocks: Set<String> = []
    @State private var blockDrafts: [String: BlockDraft] = [:]
    @State private var currentBlockIndex = 0
    @State private var sleepTime = ""
    @State private var wakeTime = ""
    @State private var typicalSleepHours = 7.5
    @State private var crashWindows: Set<String> = []
    @State private var suggestSleepAdjustments = true
    @State private var dayOpenEnergy = "med"
    @State private var dayOpenMood = ""
    @State private var isConnectingGoogle = false
    @State private var isSavingProfile = false
    @State private var isGeneratingDay = false
    @State private var hasGeneratedPlan = false

    private let blockOptions = [
        "Study",
        "Homework",
        "Classes",
        "Gym",
        "Social",
        "Clubs",
        "Content",
        "Reading",
        "Job",
        "Errands",
        "Other"
    ]
    private let timeWindowOptions = ["morning", "afternoon", "night"]
    private let crashWindowOptions = ["afternoon", "evening", "late night"]
    private let energies = ["low", "med", "high"]
    private let chipColumns = [GridItem(.adaptive(minimum: 110), spacing: 8)]

    private struct BlockDraft {
        var avgDurationMinutes = 120
        var daysPerWeek = 5
        var difficulty = 3
        var enjoyment = 3
        var bestWindows: Set<String> = ["morning"]
    }

    var body: some View {
        NavigationStack {
            ZStack {
                OmniNebulaBackground()

                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        ProgressView(value: progressValue, total: totalProgressValue)
                            .tint(Color.omniAccent)

                        switch step {
                        case 0:
                            welcomeStep
                        case 1:
                            connectGoogleStep
                        case 2:
                            weeklyBlocksStep
                        case 3:
                            hardSoftBlocksStep
                        case 4:
                            blockLoopStep
                        case 5:
                            sleepEnergyStep
                        default:
                            dayOpenStep
                        }

                        Spacer(minLength: 20)
                    }
                    .padding(24)
                }
            }
            .navigationTitle("Onboarding")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private var googleConnected: Bool {
        let status = appState.integrationsStatus
        return status?.googleCalendarConnected == true && status?.googleTasksConnected == true
    }

    private var orderedSelectedBlocks: [String] {
        blockOptions.filter { selectedBlocks.contains($0) }
    }

    private var currentBlockName: String? {
        guard currentBlockIndex < orderedSelectedBlocks.count else { return nil }
        return orderedSelectedBlocks[currentBlockIndex]
    }

    private var currentBlockDraft: BlockDraft {
        guard let currentBlockName else { return BlockDraft() }
        return blockDrafts[currentBlockName] ?? BlockDraft()
    }

    private var totalProgressValue: Double {
        Double(max(1, orderedSelectedBlocks.count + 6))
    }

    private var progressValue: Double {
        switch step {
        case 0:
            return 1
        case 1:
            return 2
        case 2:
            return 3
        case 3:
            return 4
        case 4:
            return Double(5 + min(currentBlockIndex, max(0, orderedSelectedBlocks.count - 1)))
        case 5:
            return Double(5 + orderedSelectedBlocks.count)
        default:
            return Double(6 + orderedSelectedBlocks.count)
        }
    }

    private var welcomeStep: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Omni runs your day like an OS.")
                .font(.title2.bold())
                .foregroundStyle(.white)

            Text("Plans, nudges, and adapts when you drift.")
                .foregroundStyle(Color.omniMuted)

            Button("Start Setup") {
                step = 1
            }
            .buttonStyle(.borderedProminent)
            .tint(Color.omniAccent)
        }
    }

    private var connectGoogleStep: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Connect Google")
                .font(.title2.bold())
                .foregroundStyle(.white)

            Text("Connect Calendar + Tasks so Omni can build your day.")
                .foregroundStyle(Color.omniMuted)

            if googleConnected {
                Label("Omni can now see constraints and workload.", systemImage: "checkmark.circle.fill")
                    .foregroundStyle(Color.omniAccent)
                    .font(.subheadline.weight(.semibold))
            }

            if googleConnected == false {
                Button {
                    Task {
                        guard isConnectingGoogle == false else { return }
                        isConnectingGoogle = true
                        _ = await appState.connectGoogle()
                        isConnectingGoogle = false
                    }
                } label: {
                    HStack(spacing: 8) {
                        if isConnectingGoogle {
                            ProgressView()
                                .controlSize(.small)
                        }
                        Text("Connect Google")
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(Color.omniAccent)
                .disabled(isConnectingGoogle)
            }

            Button("Continue") {
                step = 2
            }
            .buttonStyle(.bordered)
            .disabled(googleConnected == false)
        }
    }

    private var weeklyBlocksStep: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Choose Your Weekly Blocks")
                .font(.title2.bold())
                .foregroundStyle(.white)

            Text("Select the blocks Omni should optimize around.")
                .foregroundStyle(Color.omniMuted)

            LazyVGrid(columns: chipColumns, alignment: .leading, spacing: 8) {
                ForEach(blockOptions, id: \.self) { block in
                    chip(
                        title: block,
                        selected: selectedBlocks.contains(block)
                    ) {
                        toggleChip(block, in: &selectedBlocks)
                    }
                }
            }

            Button("Next") {
                for block in orderedSelectedBlocks {
                    if blockDrafts[block] == nil {
                        blockDrafts[block] = BlockDraft()
                    }
                }
                if hardBlocks.isEmpty {
                    hardBlocks = Set(orderedSelectedBlocks.filter(defaultHardBlock))
                }
                currentBlockIndex = 0
                step = 3
            }
            .buttonStyle(.borderedProminent)
            .tint(Color.omniAccent)
            .disabled(orderedSelectedBlocks.isEmpty)
        }
    }

    private var hardSoftBlocksStep: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Hard vs Soft Blocks")
                .font(.title2.bold())
                .foregroundStyle(.white)

            Text("Hard blocks stay fixed in Calendar (opaque). Soft blocks are flexible (translucent).")
                .foregroundStyle(Color.omniMuted)

            ForEach(orderedSelectedBlocks, id: \.self) { block in
                HStack {
                    Text(block)
                        .foregroundStyle(.white)
                    Spacer()
                    Picker("", selection: Binding(
                        get: { hardBlocks.contains(block) ? "hard" : "soft" },
                        set: { value in
                            if value == "hard" {
                                hardBlocks.insert(block)
                            } else {
                                hardBlocks.remove(block)
                            }
                        }
                    )) {
                        Text("Hard").tag("hard")
                        Text("Soft").tag("soft")
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 150)
                }
                .padding(10)
                .background(Color.white.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }

            Button("Continue") {
                step = 4
            }
            .buttonStyle(.borderedProminent)
            .tint(Color.omniAccent)
        }
    }

    private var blockLoopStep: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let blockName = currentBlockName {
                Text("Block Profile")
                    .font(.title2.bold())
                    .foregroundStyle(.white)
                Text("\(currentBlockIndex + 1) of \(orderedSelectedBlocks.count): \(blockName)")
                    .foregroundStyle(Color.omniMuted)

                Stepper(
                    "Avg duration/day: \(currentBlockDraft.avgDurationMinutes) min",
                    value: Binding(
                        get: { currentBlockDraft.avgDurationMinutes },
                        set: { value in
                            updateCurrentBlockDraft { draft in
                                draft.avgDurationMinutes = value
                            }
                        }
                    ),
                    in: 15...600,
                    step: 15
                )
                .foregroundStyle(.white)

                Stepper(
                    "Days/week: \(currentBlockDraft.daysPerWeek)",
                    value: Binding(
                        get: { currentBlockDraft.daysPerWeek },
                        set: { value in
                            updateCurrentBlockDraft { draft in
                                draft.daysPerWeek = value
                            }
                        }
                    ),
                    in: 1...7
                )
                .foregroundStyle(.white)

                Stepper(
                    "Difficulty: \(currentBlockDraft.difficulty)/5",
                    value: Binding(
                        get: { currentBlockDraft.difficulty },
                        set: { value in
                            updateCurrentBlockDraft { draft in
                                draft.difficulty = value
                            }
                        }
                    ),
                    in: 1...5
                )
                .foregroundStyle(.white)

                Stepper(
                    "Enjoyment: \(currentBlockDraft.enjoyment)/5",
                    value: Binding(
                        get: { currentBlockDraft.enjoyment },
                        set: { value in
                            updateCurrentBlockDraft { draft in
                                draft.enjoyment = value
                            }
                        }
                    ),
                    in: 1...5
                )
                .foregroundStyle(.white)

                Text("Best time window")
                    .font(.headline)
                    .foregroundStyle(.white)

                LazyVGrid(columns: chipColumns, alignment: .leading, spacing: 8) {
                    ForEach(timeWindowOptions, id: \.self) { window in
                        chip(
                            title: window.capitalized,
                            selected: currentBlockDraft.bestWindows.contains(window)
                        ) {
                            updateCurrentBlockDraft { draft in
                                toggleChip(window, in: &draft.bestWindows)
                            }
                        }
                    }
                }

                Button(isLastBlock ? "Done" : "Save & Next") {
                    if isLastBlock {
                        step = 5
                    } else {
                        currentBlockIndex += 1
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(Color.omniAccent)
                .disabled(currentBlockDraft.bestWindows.isEmpty)
            } else {
                Text("No block selected.")
                    .foregroundStyle(Color.omniMuted)
            }
        }
    }

    private var sleepEnergyStep: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Sleep & Energy Profile")
                .font(.title2.bold())
                .foregroundStyle(.white)

            TextField("Usual sleep time (e.g. 11:30 PM)", text: $sleepTime)
                .padding(12)
                .background(Color.white.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .foregroundStyle(.white)

            TextField("Usual wake time (e.g. 7:00 AM)", text: $wakeTime)
                .padding(12)
                .background(Color.white.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .foregroundStyle(.white)

            Stepper(
                "Typical sleep duration: \(String(format: "%.1f", typicalSleepHours)) h",
                value: $typicalSleepHours,
                in: 3...12,
                step: 0.5
            )
            .foregroundStyle(.white)

            Text("When do you crash?")
                .font(.headline)
                .foregroundStyle(.white)

            LazyVGrid(columns: chipColumns, alignment: .leading, spacing: 8) {
                ForEach(crashWindowOptions, id: \.self) { window in
                    chip(
                        title: window.capitalized,
                        selected: crashWindows.contains(window)
                    ) {
                        toggleChip(window, in: &crashWindows)
                    }
                }
            }

            Toggle("Let Omni suggest sleep/wake adjustments", isOn: $suggestSleepAdjustments)
                .tint(Color.omniAccent)
                .foregroundStyle(.white)

            Button {
                Task {
                    guard isSavingProfile == false else { return }
                    isSavingProfile = true

                    let weeklyPayload: [OnboardingWeeklyBlockProfile] = orderedSelectedBlocks.compactMap { blockName -> OnboardingWeeklyBlockProfile? in
                        guard let draft = blockDrafts[blockName] else { return nil }
                        return OnboardingWeeklyBlockProfile(
                            name: blockName,
                            avgDurationMinutes: draft.avgDurationMinutes,
                            daysPerWeek: draft.daysPerWeek,
                            difficulty: draft.difficulty,
                            enjoyment: draft.enjoyment,
                            bestWindows: draft.bestWindows.sorted()
                        )
                    }

                    let sleepPayload = OnboardingSleepEnergyProfile(
                        usualSleepTime: sleepTime,
                        usualWakeTime: wakeTime,
                        typicalSleepHours: typicalSleepHours,
                        crashWindows: crashWindows.sorted(),
                        suggestSleepAdjustments: suggestSleepAdjustments
                    )

                    let saved = await appState.saveOnboardingIntake(
                        weeklyBlocks: weeklyPayload,
                        sleepEnergy: sleepPayload,
                        blockPreferences: OnboardingBlockPreferences(
                            hardBlocks: hardBlocksPayload,
                            softBlocks: softBlocksPayload
                        )
                    )
                    isSavingProfile = false

                    if saved {
                        step = 6
                    }
                }
            } label: {
                HStack(spacing: 8) {
                    if isSavingProfile {
                        ProgressView()
                            .controlSize(.small)
                    }
                    Text(isSavingProfile ? "Saving..." : "Continue")
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(Color.omniAccent)
            .disabled(isSavingProfile || sleepTime.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || wakeTime.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
    }

    private var dayOpenStep: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("First Plan Generation")
                .font(.title2.bold())
                .foregroundStyle(.white)

            Picker("Energy", selection: $dayOpenEnergy) {
                ForEach(energies, id: \.self) { value in
                    Text(value.capitalized).tag(value)
                }
            }
            .pickerStyle(.segmented)

            TextField("Mood (optional)", text: $dayOpenMood)
                .padding(12)
                .background(Color.white.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .foregroundStyle(.white)

            Button {
                Task {
                    guard isGeneratingDay == false else { return }
                    isGeneratingDay = true
                    hasGeneratedPlan = await appState.generateDay(
                        energy: dayOpenEnergy,
                        mood: dayOpenMood,
                        stickyBlocks: hardBlocksPayload
                    )
                    isGeneratingDay = false
                }
            } label: {
                HStack(spacing: 8) {
                    if isGeneratingDay {
                        ProgressView()
                            .controlSize(.small)
                    }
                    Text(isGeneratingDay ? "Generating..." : "Generate My Day")
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(Color.omniAccent)
            .disabled(isGeneratingDay)

            if hasGeneratedPlan, let generatedPlan = appState.planStore.plan {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Preview")
                        .font(.headline)
                        .foregroundStyle(.white)

                    Text("Today’s Top 3 Outcomes")
                        .font(.subheadline.bold())
                        .foregroundStyle(Color.omniMuted)

                    ForEach(Array(generatedPlan.topOutcomes.prefix(3)), id: \.self) { outcome in
                        Text("• \(outcome)")
                            .foregroundStyle(.white)
                    }

                    Text("Draft blocks around calendar events")
                        .font(.subheadline.bold())
                        .foregroundStyle(Color.omniMuted)

                    ForEach(Array(generatedPlan.blocks.prefix(3)), id: \.effectiveId) { block in
                        Text("• \(block.label)")
                            .foregroundStyle(.white)
                    }

                    Text("Suggested Shutdown Target")
                        .font(.subheadline.bold())
                        .foregroundStyle(Color.omniMuted)
                    Text(generatedPlan.shutdownSuggestion ?? "No shutdown target suggested yet.")
                        .foregroundStyle(.white)
                }
                .padding(12)
                .background(Color.black.opacity(0.35))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }

            Button("Start Day") {
                appState.setOnboardingComplete()
            }
            .buttonStyle(.borderedProminent)
            .tint(Color.omniAccent)
            .disabled(hasGeneratedPlan == false)
        }
    }

    private var isLastBlock: Bool {
        currentBlockIndex >= max(0, orderedSelectedBlocks.count - 1)
    }

    private var hardBlocksPayload: [String] {
        orderedSelectedBlocks.filter { hardBlocks.contains($0) }
    }

    private var softBlocksPayload: [String] {
        orderedSelectedBlocks.filter { hardBlocks.contains($0) == false }
    }

    private func defaultHardBlock(_ blockName: String) -> Bool {
        let normalized = blockName.lowercased()
        return normalized == "classes" || normalized == "job" || normalized == "errands"
    }

    private func updateCurrentBlockDraft(_ update: (inout BlockDraft) -> Void) {
        guard let name = currentBlockName else { return }
        var draft = blockDrafts[name] ?? BlockDraft()
        update(&draft)
        blockDrafts[name] = draft
    }

    private func toggleChip(_ value: String, in set: inout Set<String>) {
        if set.contains(value) {
            set.remove(value)
        } else {
            set.insert(value)
        }
    }

    private func chip(title: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.footnote.weight(.semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .padding(.horizontal, 10)
                .background(selected ? Color.omniAccent.opacity(0.25) : Color.white.opacity(0.1))
                .foregroundStyle(selected ? Color.omniAccent : Color.white)
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}
