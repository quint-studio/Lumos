import SwiftUI

struct ContentView: View {
    @Environment(AccountManager.self) var accountManager
    @EnvironmentObject var notificationManager: NotificationManager
    @State private var webControllers: [UUID: LumosWebViewController] = [:]
    @State private var showSidebar = true

    var body: some View {
        HStack(spacing: 0) {
            if showSidebar {
                AccountIconSidebar()
                    .background(.background.opacity(0.6))
                    .transition(.move(edge: .leading).combined(with: .opacity))

                Divider()
            }

            ZStack {
                Color(nsColor: .windowBackgroundColor)

                ForEach(accountManager.accounts) { account in
                    webView(for: account)
                        .opacity(account.id == accountManager.activeAccountId ? 1 : 0)
                        .allowsHitTesting(account.id == accountManager.activeAccountId)
                }
            }
        }
        .frame(minWidth: 500, minHeight: 400)
        .toolbar {
            ToolbarItem(placement: .navigation) {
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) { showSidebar.toggle() }
                } label: {
                    Image(systemName: "sidebar.left")
                }
                .help("Ẩn/hiện sidebar (⌘\\)")
            }

            ToolbarItem(placement: .primaryAction) {
                Button {
                    currentController()?.reload()
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .help("Tải lại (⌘R)")
                .keyboardShortcut("r", modifiers: .command)
            }

            ToolbarItem(placement: .primaryAction) {
                Button {
                    (NSApp.delegate as? AppDelegate)?.updaterController.updater.checkForUpdates()
                } label: {
                    Image(systemName: "arrow.down.circle")
                }
                .help("Kiểm tra cập nhật")
            }
        }
        // Cmd+\ để toggle sidebar
        .background {
            Button("") { withAnimation(.easeInOut(duration: 0.2)) { showSidebar.toggle() } }
                .keyboardShortcut("\\", modifiers: .command)
                .opacity(0)
                .frame(width: 0, height: 0)
        }
        .onAppear { syncControllers() }
        .onChange(of: accountManager.accounts) { syncControllers() }
    }

    // MARK: - Helpers

    @ViewBuilder
    private func webView(for account: Account) -> some View {
        if let controller = webControllers[account.id] {
            WebContainerView(controller: controller)
        }
    }

    private func currentController() -> LumosWebViewController? {
        guard let id = accountManager.activeAccountId else { return nil }
        return webControllers[id]
    }

    private func syncControllers() {
        let existingIds = Set(webControllers.keys)
        let currentIds = Set(accountManager.accounts.map(\.id))

        for id in existingIds.subtracting(currentIds) {
            webControllers.removeValue(forKey: id)
        }

        for account in accountManager.accounts where !existingIds.contains(account.id) {
            webControllers[account.id] = LumosWebViewController(
                account: account,
                accountManager: accountManager,
                notificationManager: notificationManager
            )
        }
    }
}

struct AccountCommands: Commands {
    var body: some Commands {
        CommandMenu("Tài khoản") {
            Text("Chọn tài khoản từ sidebar")
                .disabled(true)
        }
    }
}
