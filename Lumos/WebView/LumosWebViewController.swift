import WebKit
import AppKit

// Chrome user-agent to avoid Messenger blocking the WKWebView
private let kUserAgent = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36"
private let kMessengerURL = URL(string: "https://www.messenger.com")!

final class LumosWebViewController: NSObject {
    let webView: WKWebView
    let account: Account
    weak var accountManager: AccountManager?
    weak var notificationManager: NotificationManager?

    init(account: Account, accountManager: AccountManager, notificationManager: NotificationManager) {
        self.account = account
        self.accountManager = accountManager
        self.notificationManager = notificationManager

        let config = WKWebViewConfiguration()
        config.websiteDataStore = WKWebsiteDataStore(forIdentifier: account.id)
        config.defaultWebpagePreferences.allowsContentJavaScript = true

        // Allow media playback
        config.mediaTypesRequiringUserActionForPlayback = []

        let userContentController = WKUserContentController()

        // Inject notification bridge script into main frame only
        if let scriptURL = Bundle.main.url(forResource: "notification_bridge", withExtension: "js"),
           let scriptSource = try? String(contentsOf: scriptURL) {
            let script = WKUserScript(
                source: scriptSource,
                injectionTime: .atDocumentStart,
                forMainFrameOnly: true
            )
            userContentController.addUserScript(script)
        }

        config.userContentController = userContentController

        webView = WKWebView(frame: .zero, configuration: config)
        webView.customUserAgent = kUserAgent
        webView.allowsBackForwardNavigationGestures = true
        webView.pageZoom = 0.8

        #if DEBUG
        webView.isInspectable = true
        #endif

        super.init()

        // Add message handlers after super.init
        userContentController.add(self, name: "notifications")
        userContentController.add(self, name: "badgeCount")

        webView.navigationDelegate = self
        webView.uiDelegate = self
        load()
    }

    deinit {
        webView.configuration.userContentController.removeScriptMessageHandler(forName: "notifications")
        webView.configuration.userContentController.removeScriptMessageHandler(forName: "badgeCount")
    }

    func load() {
        let request = URLRequest(url: kMessengerURL)
        webView.load(request)
    }

    func reload() {
        if webView.url == nil {
            load()
        } else {
            webView.reload()
        }
    }
}

// MARK: - WKScriptMessageHandler
extension LumosWebViewController: WKScriptMessageHandler {
    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        switch message.name {
        case "notifications":
            handleNotification(message.body)
        case "badgeCount":
            handleBadgeCount(message.body)
        default:
            break
        }
    }

    private func handleNotification(_ body: Any) {
        guard let dict = body as? [String: String] else { return }
        let title = dict["title"] ?? ""
        let bodyText = dict["body"] ?? ""
        notificationManager?.post(
            title: title,
            body: bodyText,
            accountId: account.id,
            accountName: account.name
        )
    }

    private func handleBadgeCount(_ body: Any) {
        let count: Int
        if let n = body as? Int {
            count = n
        } else if let s = body as? String, let n = Int(s) {
            count = n
        } else {
            count = 0
        }
        DispatchQueue.main.async { [weak self] in
            guard let self, let mgr = self.accountManager else { return }
            mgr.unreadCounts[self.account.id] = count
            self.notificationManager?.updateBadge(total: mgr.totalUnread())
        }
    }
}

// MARK: - WKNavigationDelegate
extension LumosWebViewController: WKNavigationDelegate {
    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        guard let url = navigationAction.request.url else {
            decisionHandler(.cancel)
            return
        }

        // Allow inert/iframe transitions (about:blank, about:srcdoc) — used by JS for
        // postMessage targets, sandboxed iframes, and window.open popup hand-offs.
        if url.scheme == "about" {
            decisionHandler(.allow)
            return
        }

        let host = url.host ?? ""
        // Meta family domains used during messenger/facebook/instagram login flows
        // (incl. Accounts Center: accountscenter.meta.com, meta.com splash, fbcdn assets,
        //  fbsbx.com which hosts the pre-auth reCAPTCHA iframe).
        let isAllowedDomain = host == "messenger.com" || host.hasSuffix(".messenger.com")
                           || host == "facebook.com"  || host.hasSuffix(".facebook.com")
                           || host == "instagram.com" || host.hasSuffix(".instagram.com")
                           || host == "meta.com"      || host.hasSuffix(".meta.com")
                           || host == "fb.com"        || host.hasSuffix(".fb.com")
                           || host == "fbsbx.com"     || host.hasSuffix(".fbsbx.com")
                           || host.hasSuffix(".fbcdn.net")
                           // Google reCAPTCHA used inside FB's pre-auth captcha iframe.
                           || host == "google.com"    || host.hasSuffix(".google.com")
                           || host == "gstatic.com"   || host.hasSuffix(".gstatic.com")
                           || host == "recaptcha.net" || host.hasSuffix(".recaptcha.net")

        if isAllowedDomain {
            decisionHandler(.allow)
        } else {
            #if DEBUG
            print("[Lumos] Blocked navigation: \(url.absoluteString) (type: \(navigationAction.navigationType.rawValue))")
            #endif
            // Open external links in default browser, only http/https schemes
            if navigationAction.navigationType == .linkActivated,
               let scheme = url.scheme, scheme == "https" || scheme == "http" {
                NSWorkspace.shared.open(url)
            }
            decisionHandler(.cancel)
        }
    }
}

// MARK: - WKUIDelegate
extension LumosWebViewController: WKUIDelegate {
    // Some Meta login flows open a popup via window.open(). Without this delegate
    // WKWebView silently drops the request, leaving the user stuck on a blank/Meta-icon page.
    // Load the popup URL into the current webview instead of creating a new window.
    func webView(_ webView: WKWebView,
                 createWebViewWith configuration: WKWebViewConfiguration,
                 for navigationAction: WKNavigationAction,
                 windowFeatures: WKWindowFeatures) -> WKWebView? {
        if navigationAction.targetFrame == nil, let url = navigationAction.request.url {
            let host = url.host ?? ""
            let isMetaFamily = host.hasSuffix("messenger.com") || host.hasSuffix("facebook.com")
                            || host.hasSuffix("instagram.com") || host.hasSuffix("meta.com")
                            || host.hasSuffix("fb.com")
            if isMetaFamily {
                webView.load(navigationAction.request)
            } else if let scheme = url.scheme, scheme == "https" || scheme == "http" {
                NSWorkspace.shared.open(url)
            }
        }
        return nil
    }
}
