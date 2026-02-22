import SwiftUI

struct AppRootView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        Group {
            if appState.sessionStore.isAuthenticated == false {
                AuthView()
                    .environmentObject(appState)
            } else if appState.sessionStore.onboardingComplete == false {
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
            appState.handleDeepLink(url)
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
