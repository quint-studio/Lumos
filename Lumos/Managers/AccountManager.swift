import Foundation
import Observation

@Observable
final class AccountManager {
    private(set) var accounts: [Account] = []
    private(set) var activeAccountId: UUID?

    // Unread counts per account, updated by badge bridge
    var unreadCounts: [UUID: Int] = [:]

    private let storageKey = "messenger.accounts"
    private let activeKey = "messenger.activeAccount"

    init() {
        load()
        if accounts.isEmpty {
            let first = Account(name: "Tài khoản 1")
            accounts.append(first)
            activeAccountId = first.id
            save()
        }
    }

    var activeAccount: Account? {
        accounts.first { $0.id == activeAccountId }
    }

    func setActiveAccount(id: UUID) {
        guard accounts.contains(where: { $0.id == id }) else { return }
        activeAccountId = id
        UserDefaults.standard.set(id.uuidString, forKey: activeKey)
    }

    func addAccount(name: String) {
        let account = Account(name: name.isEmpty ? "Tài khoản \(accounts.count + 1)" : name)
        accounts.append(account)
        save()
        setActiveAccount(id: account.id)
    }

    func removeAccount(id: UUID) {
        accounts.removeAll { $0.id == id }
        unreadCounts.removeValue(forKey: id)
        // Switch active if needed
        if activeAccountId == id {
            activeAccountId = accounts.first?.id
        }
        save()
        // Clean up WebKit data store for removed account
        Task {
            let store = WKWebsiteDataStore(forIdentifier: id)
            let types = WKWebsiteDataStore.allWebsiteDataTypes()
            let records = await store.dataRecords(ofTypes: types)
            await store.removeData(ofTypes: types, for: records)
        }
    }

    func updateName(_ name: String, for id: UUID) {
        if let idx = accounts.firstIndex(where: { $0.id == id }) {
            accounts[idx].name = name
            save()
        }
    }

    func totalUnread() -> Int {
        unreadCounts.values.reduce(0, +)
    }

    private func save() {
        if let data = try? JSONEncoder().encode(accounts) {
            UserDefaults.standard.set(data, forKey: storageKey)
        }
    }

    private func load() {
        if let data = UserDefaults.standard.data(forKey: storageKey),
           let saved = try? JSONDecoder().decode([Account].self, from: data) {
            accounts = saved
        }
        if let idStr = UserDefaults.standard.string(forKey: activeKey),
           let id = UUID(uuidString: idStr),
           accounts.contains(where: { $0.id == id }) {
            activeAccountId = id
        } else {
            activeAccountId = accounts.first?.id
        }
    }
}

// Import WebKit for cleanup
import WebKit
