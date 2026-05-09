import WebKit
import AppKit

private let kUserAgent = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36"
private let kMessengerURL = URL(string: "https://www.messenger.com")!

final class LumosWebViewController: NSObject {
    let webView: WKWebView
    let account: Account
    weak var accountManager: AccountManager?
    weak var notificationManager: NotificationManager?

    private var cookieStorageURL: URL {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = support.appendingPathComponent("Lumos/Cookies", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("\(account.id).json")
    }

    init(account: Account, accountManager: AccountManager, notificationManager: NotificationManager) {
        self.account = account
        self.accountManager = accountManager
        self.notificationManager = notificationManager

        let config = WKWebViewConfiguration()
        config.websiteDataStore = WKWebsiteDataStore(forIdentifier: account.id)
        config.defaultWebpagePreferences.allowsContentJavaScript = true
        config.mediaTypesRequiringUserActionForPlayback = []

        let userContentController = WKUserContentController()
        if let scriptURL = Bundle.main.url(forResource: "notification_bridge", withExtension: "js"),
           let scriptSource = try? String(contentsOf: scriptURL) {
            userContentController.addUserScript(WKUserScript(
                source: scriptSource,
                injectionTime: .atDocumentStart,
                forMainFrameOnly: true
            ))
        }
        config.userContentController = userContentController

        webView = WKWebView(frame: .zero, configuration: config)
        webView.customUserAgent = kUserAgent
        webView.allowsBackForwardNavigationGestures = true
        webView.pageZoom = 0.8

        super.init()

        userContentController.add(self, name: "notifications")
        userContentController.add(self, name: "badgeCount")
        webView.navigationDelegate = self

        // Restore saved cookies trước khi load
        restoreCookies { [weak self] in
            self?.load()
        }
    }

    deinit {
        webView.configuration.userContentController.removeScriptMessageHandler(forName: "notifications")
        webView.configuration.userContentController.removeScriptMessageHandler(forName: "badgeCount")
    }

    func load() {
        webView.load(URLRequest(url: kMessengerURL))
    }

    func reload() {
        if webView.url == nil { load() } else { webView.reload() }
    }

    // MARK: - Cookie persistence

    func saveCookies(completion: (() -> Void)? = nil) {
        webView.configuration.websiteDataStore.httpCookieStore.getAllCookies { [weak self] cookies in
            guard let self else { completion?(); return }
            let expiry = Date(timeIntervalSinceNow: 30 * 24 * 3600)
            let serializable = cookies.compactMap { cookie -> [String: Any]? in
                guard var props = cookie.properties else { return nil }
                // Give session cookies a 30-day expiry so they restore as persistent
                if cookie.isSessionOnly {
                    props[.expires] = expiry
                }
                var dict: [String: Any] = [:]
                for (key, value) in props {
                    // NSDate is not JSON-serializable — convert to TimeInterval
                    if let date = value as? Date {
                        dict[key.rawValue] = date.timeIntervalSince1970
                    } else {
                        dict[key.rawValue] = value
                    }
                }
                return dict
            }
            if let data = try? JSONSerialization.data(withJSONObject: serializable) {
                try? data.write(to: self.cookieStorageURL, options: .atomic)
            }
            completion?()
        }
    }

    private func restoreCookies(completion: @escaping () -> Void) {
        guard let data = try? Data(contentsOf: cookieStorageURL),
              let array = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]]
        else { completion(); return }

        let store = webView.configuration.websiteDataStore.httpCookieStore
        let group = DispatchGroup()

        for dict in array {
            var props: [HTTPCookiePropertyKey: Any] = [:]
            for (key, value) in dict {
                let propKey = HTTPCookiePropertyKey(rawValue: key)
                // Expires was stored as TimeInterval — convert back to Date
                if propKey == .expires, let ti = value as? TimeInterval {
                    props[propKey] = Date(timeIntervalSince1970: ti)
                } else {
                    props[propKey] = value
                }
            }
            if let cookie = HTTPCookie(properties: props) {
                group.enter()
                store.setCookie(cookie) { group.leave() }
            }
        }

        group.notify(queue: .main) { completion() }
    }
}

// MARK: - WKScriptMessageHandler
extension LumosWebViewController: WKScriptMessageHandler {
    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        switch message.name {
        case "notifications": handleNotification(message.body)
        case "badgeCount":    handleBadgeCount(message.body)
        default: break
        }
    }

    private func handleNotification(_ body: Any) {
        guard let dict = body as? [String: String] else { return }
        notificationManager?.post(
            title: dict["title"] ?? "",
            body: dict["body"] ?? "",
            accountId: account.id,
            accountName: account.name
        )
    }

    private func handleBadgeCount(_ body: Any) {
        let count: Int
        if let n = body as? Int { count = n }
        else if let s = body as? String, let n = Int(s) { count = n }
        else { count = 0 }

        DispatchQueue.main.async { [weak self] in
            guard let self, let mgr = self.accountManager else { return }
            mgr.unreadCounts[self.account.id] = count
            self.notificationManager?.updateBadge(total: mgr.totalUnread())
        }
    }
}

// MARK: - WKNavigationDelegate
extension LumosWebViewController: WKNavigationDelegate {
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        // Save cookies sau mỗi lần trang load xong
        saveCookies()
    }

    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction,
                 decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        guard let url = navigationAction.request.url else { decisionHandler(.cancel); return }

        let host = url.host ?? ""
        let isAllowedDomain = host == "messenger.com" || host.hasSuffix(".messenger.com")
                           || host == "facebook.com"  || host.hasSuffix(".facebook.com")
                           || host == "instagram.com" || host.hasSuffix(".instagram.com")

        if isAllowedDomain {
            decisionHandler(.allow)
        } else {
            if navigationAction.navigationType == .linkActivated,
               let scheme = url.scheme, scheme == "https" || scheme == "http" {
                NSWorkspace.shared.open(url)
            }
            decisionHandler(.cancel)
        }
    }
}
