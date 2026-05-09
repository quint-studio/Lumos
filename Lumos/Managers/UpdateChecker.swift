import Foundation
import AppKit

final class UpdateChecker {
    // Đổi thành GitHub repo của bạn
    private static let releasesAPI = "https://api.github.com/repos/quint-studio/Lumos/releases/latest"

    static func checkOnLaunch() {
        // Delay 3s sau khi launch để không block UI
        DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + 3) {
            check(silent: true)
        }
    }

    static func checkManually() {
        DispatchQueue.global(qos: .userInitiated).async {
            check(silent: false)
        }
    }

    private static func check(silent: Bool) {
        guard let url = URL(string: releasesAPI) else { return }

        var request = URLRequest(url: url)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")

        URLSession.shared.dataTask(with: request) { data, _, error in
            guard let data, error == nil,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let tagName = json["tag_name"] as? String,
                  let htmlURL = json["html_url"] as? String,
                  let releaseURL = URL(string: htmlURL)
            else {
                if !silent { showError() }
                return
            }

            let latest = tagName.trimmingCharacters(in: .init(charactersIn: "v"))
            let current = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0"

            if isNewer(latest, than: current) {
                DispatchQueue.main.async {
                    showUpdateAlert(version: tagName, url: releaseURL)
                }
            } else if !silent {
                DispatchQueue.main.async {
                    showUpToDateAlert(current: current)
                }
            }
        }.resume()
    }

    private static func showUpdateAlert(version: String, url: URL) {
        let alert = NSAlert()
        alert.messageText = "Có phiên bản mới: \(version)"
        alert.informativeText = "Bạn đang dùng \(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "").\nTải về phiên bản mới nhất?"
        alert.addButton(withTitle: "Tải về")
        alert.addButton(withTitle: "Bỏ qua")
        alert.alertStyle = .informational

        if alert.runModal() == .alertFirstButtonReturn {
            NSWorkspace.shared.open(url)
        }
    }

    private static func showUpToDateAlert(current: String) {
        let alert = NSAlert()
        alert.messageText = "Bạn đang dùng phiên bản mới nhất"
        alert.informativeText = "Lumos \(current) là phiên bản mới nhất."
        alert.addButton(withTitle: "OK")
        alert.alertStyle = .informational
        alert.runModal()
    }

    private static func showError() {
        DispatchQueue.main.async {
            let alert = NSAlert()
            alert.messageText = "Không kiểm tra được cập nhật"
            alert.informativeText = "Vui lòng kiểm tra kết nối mạng."
            alert.addButton(withTitle: "OK")
            alert.runModal()
        }
    }

    // So sánh semver: "1.2.0" > "1.1.3"
    private static func isNewer(_ latest: String, than current: String) -> Bool {
        let l = latest.split(separator: ".").compactMap { Int($0) }
        let c = current.split(separator: ".").compactMap { Int($0) }
        for i in 0..<max(l.count, c.count) {
            let lv = i < l.count ? l[i] : 0
            let cv = i < c.count ? c[i] : 0
            if lv != cv { return lv > cv }
        }
        return false
    }
}
