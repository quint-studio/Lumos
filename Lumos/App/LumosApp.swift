import SwiftUI

@main
struct LumosApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(appDelegate.accountManager)
                .environmentObject(appDelegate.notificationManager)
        }
        .windowStyle(.titleBar)
        .windowToolbarStyle(.unifiedCompact(showsTitle: false))
        .commands {
            CommandGroup(replacing: .newItem) {}
            CommandGroup(after: .appInfo) {
                Button("Kiểm tra cập nhật...") {
                    UpdateChecker.checkManually()
                }
            }
            AccountCommands()
        }
    }
}
