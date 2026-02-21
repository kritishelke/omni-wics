import DeviceActivity
import UserNotifications
import Foundation

struct ExtensionDriftEvent: Codable {
    let id: String
    let ts: String
    let minutes: Int?
    let blockId: String?
    let apps: [String]
}

final class ExtensionDriftStore {
    static let key = "omni.drift.events"
    static let appGroupId = "group.com.example.omni" // Replace with real app group in both targets.

    static func append(_ event: ExtensionDriftEvent) {
        let defaults = UserDefaults(suiteName: appGroupId) ?? .standard
        let existing: [ExtensionDriftEvent]

        if let data = defaults.data(forKey: key),
           let parsed = try? JSONDecoder().decode([ExtensionDriftEvent].self, from: data) {
            existing = parsed
        } else {
            existing = []
        }

        var updated = existing
        updated.append(event)

        if let data = try? JSONEncoder().encode(updated) {
            defaults.set(data, forKey: key)
        }
    }
}

final class OmniDeviceActivityMonitorExtension: DeviceActivityMonitor {
    override func eventDidReachThreshold(
        _ event: DeviceActivityEvent.Name,
        activity: DeviceActivityName
    ) {
        let defaults = UserDefaults(suiteName: ExtensionDriftStore.appGroupId) ?? .standard
        let blockId = defaults.string(forKey: "omni.current.block.id")

        let driftEvent = ExtensionDriftEvent(
            id: UUID().uuidString,
            ts: ISO8601DateFormatter().string(from: Date()),
            minutes: 5,
            blockId: blockId,
            apps: ["screenTime"]
        )
        ExtensionDriftStore.append(driftEvent)

        let content = UNMutableNotificationContent()
        content.title = "You drifted"
        content.body = "Swap, shrink, or reset your block in Omni"
        content.sound = .default
        content.userInfo = ["deepLink": "omni://now"]

        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(request)
    }
}
