import AppKit
import UserNotifications
import WebKit

final class AppDelegate: NSObject, NSApplicationDelegate, UNUserNotificationCenterDelegate {
    let accountManager = AccountManager()
    let notificationManager = NotificationManager()

    func applicationDidFinishLaunching(_ notification: Notification) {
        notificationManager.requestPermission()
        UNUserNotificationCenter.current().delegate = self
        NSApp.setActivationPolicy(.regular)
        UpdateChecker.checkOnLaunch()
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag {
            sender.windows.first?.makeKeyAndOrderFront(nil)
        }
        return true
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        NSApp.dockTile.badgeLabel = nil
        persistSessionCookies(for: accountManager.accounts) {
            sender.reply(toApplicationShouldTerminate: true)
        }
        return .terminateLater
    }

    // Messenger dùng session cookies (không có expires) — WKWebsiteDataStore không giữ chúng
    // giữa các lần chạy app. Fix: convert sang persistent cookies trước khi thoát.
    private func persistSessionCookies(for accounts: [Account], completion: @escaping () -> Void) {
        let group = DispatchGroup()

        for account in accounts {
            group.enter()
            let store = WKWebsiteDataStore(forIdentifier: account.id)
            store.httpCookieStore.getAllCookies { cookies in
                let sessionCookies = cookies.filter { $0.isSessionOnly }
                guard !sessionCookies.isEmpty else { group.leave(); return }

                let inner = DispatchGroup()
                for cookie in sessionCookies {
                    var props = cookie.properties ?? [:]
                    props[.expires] = Date(timeIntervalSinceNow: 30 * 24 * 3600) // 30 ngày
                    if let persistent = HTTPCookie(properties: props) {
                        inner.enter()
                        store.httpCookieStore.setCookie(persistent) { inner.leave() }
                    }
                }
                inner.notify(queue: .main) { group.leave() }
            }
        }

        group.notify(queue: .main) { completion() }
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
