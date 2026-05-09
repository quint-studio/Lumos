import Foundation
import UserNotifications
import AppKit

final class NotificationManager: ObservableObject {
    func requestPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if let error { print("Notification permission error: \(error)") }
        }
    }

    func post(title: String, body: String, accountId: UUID, accountName: String) {
        let content = UNMutableNotificationContent()
        content.title = title.isEmpty ? accountName : title
        content.body = body
        content.sound = .default
        content.userInfo = ["accountId": accountId.uuidString]

        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(request)
    }

    func updateBadge(total: Int) {
        DispatchQueue.main.async {
            NSApp.dockTile.badgeLabel = total > 0 ? "\(total)" : nil
        }
    }
}
