import SwiftUI

struct AccountIconSidebar: View {
    @Environment(AccountManager.self) var accountManager
    @State private var showingAddSheet = false
    @State private var editingAccount: Account?

    var body: some View {
        VStack(spacing: 6) {
            Spacer().frame(height: 10)

            ForEach(accountManager.accounts) { account in
                let isActive = account.id == accountManager.activeAccountId
                let unread = accountManager.unreadCounts[account.id] ?? 0

                AccountAvatarButton(account: account, isActive: isActive, unread: unread) {
                    accountManager.setActiveAccount(id: account.id)
                }
                .contextMenu {
                    Button("Đổi tên") { editingAccount = account }
                    Divider()
                    Button("Xóa", role: .destructive) {
                        accountManager.removeAccount(id: account.id)
                    }
                    .disabled(accountManager.accounts.count <= 1)
                }
            }

            Spacer()

            Button { showingAddSheet = true } label: {
                Image(systemName: "plus")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.secondary)
                    .frame(width: 34, height: 34)
                    .background(.quaternary, in: Circle())
            }
            .buttonStyle(.plain)
            .help("Thêm tài khoản")

            Spacer().frame(height: 10)
        }
        .frame(width: 58)
        .sheet(isPresented: $showingAddSheet) {
            AddAccountSheet(isPresented: $showingAddSheet)
                .environment(accountManager)
        }
        .sheet(item: $editingAccount) { account in
            RenameAccountSheet(account: account, isPresented: Binding(
                get: { editingAccount != nil },
                set: { if !$0 { editingAccount = nil } }
            ))
            .environment(accountManager)
        }
    }
}

struct AccountAvatarButton: View {
    let account: Account
    let isActive: Bool
    let unread: Int
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack(alignment: .topTrailing) {
                Circle()
                    .fill(Color(nsColor: account.color).opacity(isActive ? 1.0 : 0.15))
                    .frame(width: 36, height: 36)
                    .overlay {
                        Text(String(account.name.prefix(1)).uppercased())
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(isActive ? .white : Color(nsColor: account.color))
                    }
                    .shadow(color: isActive ? Color(nsColor: account.color).opacity(0.4) : .clear, radius: 4, y: 2)

                if unread > 0 {
                    ZStack {
                        Circle().fill(Color.red).frame(width: 14, height: 14)
                        Text(unread > 9 ? "9+" : "\(unread)")
                            .font(.system(size: 7, weight: .bold))
                            .foregroundStyle(.white)
                    }
                    .offset(x: 3, y: -3)
                }
            }
        }
        .buttonStyle(.plain)
        .help(account.name + (unread > 0 ? " (\(unread))" : ""))
        .padding(.horizontal, 2)
    }
}

// MARK: - Sheets

struct AddAccountSheet: View {
    @Environment(AccountManager.self) var accountManager
    @Binding var isPresented: Bool
    @State private var name = ""
    @FocusState private var focused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Thêm tài khoản").font(.headline)

            TextField("Tên tài khoản", text: $name)
                .textFieldStyle(.roundedBorder)
                .focused($focused)
                .onSubmit { submit() }

            HStack {
                Spacer()
                Button("Huỷ") { isPresented = false }.keyboardShortcut(.escape)
                Button("Thêm") { submit() }
                    .keyboardShortcut(.return)
                    .buttonStyle(.borderedProminent)
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .padding(20)
        .frame(width: 300)
        .onAppear { focused = true }
    }

    private func submit() {
        let t = name.trimmingCharacters(in: .whitespaces)
        guard !t.isEmpty else { return }
        accountManager.addAccount(name: t)
        isPresented = false
    }
}

struct RenameAccountSheet: View {
    @Environment(AccountManager.self) var accountManager
    let account: Account
    @Binding var isPresented: Bool
    @State private var name = ""
    @FocusState private var focused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Đổi tên tài khoản").font(.headline)

            TextField("Tên tài khoản", text: $name)
                .textFieldStyle(.roundedBorder)
                .focused($focused)
                .onSubmit { submit() }

            HStack {
                Spacer()
                Button("Huỷ") { isPresented = false }.keyboardShortcut(.escape)
                Button("Lưu") { submit() }
                    .keyboardShortcut(.return)
                    .buttonStyle(.borderedProminent)
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .padding(20)
        .frame(width: 300)
        .onAppear { name = account.name; focused = true }
    }

    private func submit() {
        let t = name.trimmingCharacters(in: .whitespaces)
        guard !t.isEmpty else { return }
        accountManager.updateName(t, for: account.id)
        isPresented = false
    }
}
