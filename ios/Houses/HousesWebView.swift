// SPDX-License-Identifier: Apache-2.0
import SwiftUI
import UIKit
import WebKit

/// One web view onto the Houses app. Everything a house shows is the page's; this only keeps the page in the app
/// and sends what should leave it to the system browser.
struct HousesWebView: UIViewRepresentable {
    let start: URL
    let home: URL

    func makeCoordinator() -> Coordinator { Coordinator(home: home) }

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true
        config.mediaTypesRequiringUserActionForPlayback = []
        // The panel opens the payment page a beat after the tap, once the address is claimed (docs/apps.md).
        config.preferences.javaScriptCanOpenWindowsAutomatically = true
        let view = WKWebView(frame: .zero, configuration: config)
        view.navigationDelegate = context.coordinator
        view.uiDelegate = context.coordinator
        view.isOpaque = false
        view.backgroundColor = UIColor(named: "Night")
        view.scrollView.backgroundColor = UIColor(named: "Night")
        view.scrollView.contentInsetAdjustmentBehavior = .never
        view.allowsBackForwardNavigationGestures = false
        #if DEBUG
        view.isInspectable = true
        #endif
        view.load(URLRequest(url: start))
        return view
    }

    func updateUIView(_ view: WKWebView, context: Context) {}

    final class Coordinator: NSObject, WKNavigationDelegate, WKUIDelegate {
        let home: URL
        init(home: URL) { self.home = home }

        func webView(_ webView: WKWebView, decidePolicyFor action: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            guard let url = action.request.url else { return decisionHandler(.cancel) }
            let main = action.targetFrame?.isMainFrame ?? true
            if Shell.opensOutside(url, mainFrame: main, home: home) {
                UIApplication.shared.open(url)
                return decisionHandler(.cancel)
            }
            decisionHandler(.allow)
        }

        /// window.open and target="_blank", from the page or any house inside it: never a second web view.
        func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration, for action: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
            if let url = action.request.url {
                if Shell.opensOutside(url, mainFrame: true, home: home) { UIApplication.shared.open(url) } else { webView.load(action.request) }
            }
            return nil
        }

        /// The web content process can be ended by the system while the app is behind another; start the page again.
        func webViewWebContentProcessDidTerminate(_ webView: WKWebView) { webView.reload() }
    }
}
