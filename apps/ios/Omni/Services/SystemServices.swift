import Foundation
import UserNotifications
import FamilyControls
import DeviceActivity
import SwiftUI

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
