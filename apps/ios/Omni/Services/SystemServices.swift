import Foundation
import UserNotifications

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

            schedule(
                title: "Start \(block.label)",
                body: "Open Dashboard and begin this block.",
                at: start,
                deepLink: "omni://dashboard"
            )

            var next = start.addingTimeInterval(TimeInterval(checkinCadenceMinutes * 60))
            while next < end {
                schedule(
                    title: "Check-in for \(block.label)",
                    body: "Quick check-in keeps your plan adaptive.",
                    at: next,
                    deepLink: "omni://dashboard"
                )
                next = next.addingTimeInterval(TimeInterval(checkinCadenceMinutes * 60))
            }
        }
    }

    func scheduleNextCheckin(for block: PlanBlockDTO, cadenceMinutes: Int) {
        guard let start = block.startDate, let end = block.endDate else { return }
        let next = max(Date(), start).addingTimeInterval(TimeInterval(cadenceMinutes * 60))
        guard next < end else { return }

        schedule(
            title: "Mid-block check-in",
            body: block.label,
            at: next,
            deepLink: "omni://dashboard"
        )
    }

    private func schedule(title: String, body: String, at date: Date, deepLink: String) {
        guard date > Date() else { return }

        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        content.userInfo = ["deepLink": deepLink]

        let interval = date.timeIntervalSinceNow
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: max(1, interval), repeats: false)
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request)
    }
}

struct FocusSessionState: Hashable {
    let blockId: String
    let start: Date
    let plannedMinutes: Int

    var elapsedMinutes: Int {
        max(0, Int(Date().timeIntervalSince(start) / 60.0))
    }

    var progress: Double {
        guard plannedMinutes > 0 else { return 0 }
        return min(1, Double(elapsedMinutes) / Double(plannedMinutes))
    }
}
