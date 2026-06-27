import SwiftUI
import WebKit

struct WebPlayerView: UIViewRepresentable {
    @EnvironmentObject private var appState: AppState
    let url: URL

    func makeCoordinator() -> Coordinator {
        Coordinator(logger: appState.diagnosticsLogger)
    }

    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.allowsInlineMediaPlayback = true
        configuration.preferences.javaScriptCanOpenWindowsAutomatically = true
        configuration.mediaTypesRequiringUserActionForPlayback = []
        configuration.websiteDataStore = .default()
        let userContentController = WKUserContentController()
        userContentController.add(context.coordinator, name: "anixartLog")
        userContentController.addUserScript(WKUserScript(source: Self.consoleBridgeScript, injectionTime: .atDocumentStart, forMainFrameOnly: false))
        configuration.userContentController = userContentController
        #if os(iOS)
        configuration.allowsAirPlayForMediaPlayback = true
        #endif

        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = context.coordinator
        webView.uiDelegate = context.coordinator
        webView.allowsBackForwardNavigationGestures = true
        webView.customUserAgent = appState.config.webPlayerUserAgentProfile.userAgent
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        let profile = WebPlayerHostProfile(url: url)
        let uaProfile = appState.config.webPlayerUserAgentProfile
        context.coordinator.hostProfile = profile
        context.coordinator.userAgentProfile = uaProfile
        webView.customUserAgent = uaProfile.userAgent
        if webView.url != url {
            context.coordinator.log("WebView load requested", url: url, extra: [
                "hostProfile": profile.rawValue,
                "uaProfile": uaProfile.rawValue
            ])
            webView.load(Self.request(for: url, profile: profile))
        }
    }

    static func request(for url: URL, profile: WebPlayerHostProfile) -> URLRequest {
        var request = URLRequest(url: url)
        request.setValue("ru-RU,ru;q=0.9,en-US;q=0.8,en;q=0.7", forHTTPHeaderField: "Accept-Language")
        if profile == .kodik || profile == .anilibriaProxy {
            let origin = "\(url.scheme ?? "https")://\(url.host ?? "")"
            request.setValue(origin, forHTTPHeaderField: "Referer")
        }
        return request
    }

    static let consoleBridgeScript = """
    (function() {
      if (window.__anixartConsoleBridgeInstalled) { return; }
      window.__anixartConsoleBridgeInstalled = true;
      var oldLog = console.log;
      var oldError = console.error;
      console.log = function() {
        try { window.webkit.messageHandlers.anixartLog.postMessage({ level: 'log', message: Array.prototype.join.call(arguments, ' ') }); } catch(e) {}
        oldLog.apply(console, arguments);
      };
      console.error = function() {
        try { window.webkit.messageHandlers.anixartLog.postMessage({ level: 'error', message: Array.prototype.join.call(arguments, ' ') }); } catch(e) {}
        oldError.apply(console, arguments);
      };
    })();
    """

    final class Coordinator: NSObject, WKNavigationDelegate, WKUIDelegate, WKScriptMessageHandler {
        private let logger: DiagnosticsLogger
        var hostProfile: WebPlayerHostProfile = .generic
        var userAgentProfile: WebPlayerUserAgentProfile = .androidWebView

        init(logger: DiagnosticsLogger) {
            self.logger = logger
        }

        func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
            log("WebView didStart", url: webView.url)
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            log("WebView didFinish", url: webView.url)
            webView.evaluateJavaScript("JSON.stringify({title: document.title, videos: document.querySelectorAll('video').length, iframes: document.querySelectorAll('iframe').length})") { [weak self] result, error in
                var extra = ["hostProfile": self?.hostProfile.rawValue ?? "generic"]
                if let string = result as? String {
                    extra["domSummary"] = string
                }
                if let error {
                    extra["jsError"] = error.localizedDescription
                }
                self?.log("WebView DOM probe", url: webView.url, extra: extra)
            }
        }

        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            log("WebView didFail", url: webView.url, level: .error, extra: ["error": error.localizedDescription])
        }

        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            log("WebView didFailProvisionalNavigation", url: webView.url, level: .error, extra: ["error": error.localizedDescription])
        }

        func webView(
            _ webView: WKWebView,
            decidePolicyFor navigationAction: WKNavigationAction,
            decisionHandler: @escaping (WKNavigationActionPolicy) -> Void
        ) {
            log("WebView navigation policy", url: navigationAction.request.url, extra: [
                "navigationType": "\(navigationAction.navigationType.rawValue)",
                "targetFrame": navigationAction.targetFrame == nil ? "newWindow" : "sameFrame",
                "hostProfile": hostProfile.rawValue,
                "uaProfile": userAgentProfile.rawValue
            ])
            decisionHandler(.allow)
        }

        func webView(
            _ webView: WKWebView,
            createWebViewWith configuration: WKWebViewConfiguration,
            for navigationAction: WKNavigationAction,
            windowFeatures: WKWindowFeatures
        ) -> WKWebView? {
            if navigationAction.targetFrame == nil, let url = navigationAction.request.url {
                log("WebView popup loaded in same view", url: url)
                webView.load(WebPlayerView.request(for: url, profile: WebPlayerHostProfile(url: url)))
            }
            return nil
        }

        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            guard message.name == "anixartLog" else { return }
            let text: String
            if let object = message.body as? [String: Any] {
                text = object["message"] as? String ?? "\(object)"
            } else {
                text = "\(message.body)"
            }
            Task { @MainActor in
                logger.log(level: .info, category: .player, message: "WebView JS console", metadata: [
                    "hostProfile": hostProfile.rawValue,
                    "message": RedactionPolicy.redact(text)
                ])
            }
        }

        func log(_ message: String, url: URL?, level: DiagnosticLevel = .info, extra: [String: String] = [:]) {
            var metadata = url.map(RedactionPolicy.videoURLSummary) ?? [:]
            metadata["hostProfile"] = hostProfile.rawValue
            metadata["uaProfile"] = userAgentProfile.rawValue
            metadata.merge(extra) { _, new in new }
            Task { @MainActor in
                logger.log(level: level, category: .player, message: message, metadata: metadata)
            }
        }
    }
}
