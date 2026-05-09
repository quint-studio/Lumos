import SwiftUI
import WebKit

struct WebContainerView: NSViewRepresentable {
    let controller: LumosWebViewController

    func makeNSView(context: Context) -> WKWebView {
        controller.webView
    }

    func updateNSView(_ nsView: WKWebView, context: Context) {}
}
