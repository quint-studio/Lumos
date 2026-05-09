import AppKit
import UserNotifications

final class AppDelegate: NSObject, NSApplicationDelegate, UNUserNotificationCenterDelegate {
    let accountManager = AccountManager()
    let notificationManager = NotificationManager()

    func applicationDidFinishLaunching(_ notification: Notification) {
        notificationManager.requestPermission()
        UNUserNotificationCenter.current().delegate = self
        NSApp.setActivationPolicy(.regular)
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag {
            sender.windows.first?.makeKeyAndOrderFront(nil)
        }
        return true
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        NSApp.dockTile.badgeLabel = nil
        // Give WebKit time to flush WKWebsiteDataStore to disk before exit
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            sender.reply(toApplicationShouldTerminate: true)
        }
        return .terminateLater
    }

    // Called when user taps a notification while app is in foreground
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler handler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        handler([.banner, .sound])
    }

    // Called when user taps a notification
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler handler: @escaping () -> Void
    ) {
        let userInfo = response.notification.request.content.userInfo
        if let accountIdString = userInfo["accountId"] as? String,
           let accountId = UUID(uuidString: accountIdString) {
            DispatchQueue.main.async {
                self.accountManager.setActiveAccount(id: accountId)
                NSApp.activate(ignoringOtherApps: true)
                NSApp.windows.first?.makeKeyAndOrderFront(nil)
            }
        }
        handler()
    }
}
