import SwiftUI
import FamilyControls

struct AuthView: View {
    @EnvironmentObject var appState: AppState
    @State private var email = ""
    @State private var password = ""
    @State private var isSubmitting = false

    var body: some View {
        VStack(spacing: 24) {
            Image("AppLogo")
                .resizable()
                .scaledToFit()
                .frame(width: 88, height: 88)
                .clipShape(RoundedRectangle(cornerRadius: 18))

            Text("Omni")
                .font(.largeTitle.bold())

            Text("Sign in to start planning your day")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            VStack(spacing: 10) {
                TextField("Email", text: $email)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .keyboardType(.emailAddress)
                    .textFieldStyle(.roundedBorder)

                SecureField("Password", text: $password)
                    .textFieldStyle(.roundedBorder)
            }

            Button("Sign In") {
                submit(signup: false)
            }
            .buttonStyle(.borderedProminent)
            .disabled(isSubmitting)

            Button("Create Account") {
                submit(signup: true)
            }
            .buttonStyle(.bordered)
            .disabled(isSubmitting)

            Text("Use email/password auth via Supabase.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .padding()
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
