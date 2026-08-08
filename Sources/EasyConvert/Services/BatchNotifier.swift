import Foundation
import UserNotifications

enum BatchNotifier {
    /// Requests notification permissions on first use, then sends a local notification for multi-file batches.
    static func notify(summary: String, jobCount: Int) {
        guard jobCount > 1, !summary.isEmpty else { return }

        let center = UNUserNotificationCenter.current()
        center.requestAuthorization(options: [.alert, .sound]) { granted, _ in
            guard granted else { return }

            let content = UNMutableNotificationContent()
            content.title = "Batch Conversion Complete"
            content.body = summary
            content.sound = .default

            let request = UNNotificationRequest(
                identifier: UUID().uuidString,
                content: content,
                trigger: nil
            )

            center.add(request)
        }
    }
}
