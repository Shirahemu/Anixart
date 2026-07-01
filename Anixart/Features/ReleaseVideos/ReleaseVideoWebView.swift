import SwiftUI
import WebKit

struct ReleaseVideoWebRoute: Identifiable, Equatable {
    let url: URL
    let title: String

    var id: String {
        "\(title)|\(url.absoluteString)"
    }
}

struct ReleaseVideoWebPlayerView: View {
    @Environment(\.dismiss) private var dismiss

    let route: ReleaseVideoWebRoute

    var body: some View {
        NavigationStack {
            ReleaseVideoWebView(url: route.url)
                .ignoresSafeArea(edges: .bottom)
                .navigationTitle(route.title)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Готово") {
                            dismiss()
                        }
                    }
                }
        }
    }
}

struct ReleaseVideoWebView: UIViewRepresentable {
    let url: URL

    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.allowsInlineMediaPlayback = true
        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.allowsBackForwardNavigationGestures = true
        webView.scrollView.contentInsetAdjustmentBehavior = .never
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        if webView.url != url {
            webView.load(URLRequest(url: url))
        }
    }
}
