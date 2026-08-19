import Foundation
import UserNotifications
import AppKit

enum BatchNotifier {
    /// Plays completion sound and sends a notification if enabled.
    static func notify(summary: String, jobCount: Int) {
        if AppSettings.shared.playCompletionSound {
            TossySound.playCompletion()
        }

        guard AppSettings.shared.notifyOnComplete, jobCount > 0, !summary.isEmpty else { return }

        let center = UNUserNotificationCenter.current()
        center.requestAuthorization(options: [.alert, .sound]) { granted, _ in
            guard granted else { return }

            let content = UNMutableNotificationContent()
            content.title = jobCount == 1 ? "Conversion Complete" : "Batch Conversion Complete"
            content.body = summary

            let request = UNNotificationRequest(
                identifier: UUID().uuidString,
                content: content,
                trigger: nil
            )

            center.add(request)
        }
    }
}
