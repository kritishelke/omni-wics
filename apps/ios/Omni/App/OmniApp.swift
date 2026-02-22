import SwiftUI
import UIKit
import UserNotifications

final class OmniAppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    var onDeepLink: ((URL) -> Void)?

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        return true
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        defer { completionHandler() }

        guard
            let deepLink = response.notification.request.content.userInfo["deepLink"] as? String,
            let url = URL(string: deepLink)
        else {
            return
        }

        DispatchQueue.main.async { [weak self] in
            self?.onDeepLink?(url)
        }
    }
}

@main
struct OmniApp: App {
    @UIApplicationDelegateAdaptor(OmniAppDelegate.self) private var appDelegate
    @StateObject private var appState = AppState()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            AppRootView()
                .environmentObject(appState)
                .onAppear {
                    appDelegate.onDeepLink = { url in
                        appState.handleDeepLink(url)
                    }
                }
                .onChange(of: scenePhase) { newPhase in
                    if newPhase == .active {
                        Task {
                            await appState.refreshIfAuthenticated(fullRefresh: false)
                        }
                    }
                }
        }
    }
}
