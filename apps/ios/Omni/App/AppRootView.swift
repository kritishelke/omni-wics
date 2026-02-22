import SwiftUI

struct AppRootView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
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
