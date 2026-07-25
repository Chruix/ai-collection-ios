import SwiftUI
import WebKit

struct WebViewContainer: View {
    let apiBaseURL: String
    @Binding var showSettings: Bool
    @State private var webViewKey = 0

    var body: some View {
        ZStack(alignment: .topTrailing) {
            WebViewRepresentable(apiBaseURL: apiBaseURL)
                .id(webViewKey)
                .ignoresSafeArea()

            VStack {
                HStack {
                    Spacer()
                    Button(action: { showSettings = true }) {
                        Image(systemName: "gearshape.fill")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.secondary)
                            .frame(width: 36, height: 36)
                            .background(.ultraThinMaterial)
                            .clipShape(Circle())
                    }
                    .padding(.trailing, 16)
                    .padding(.top, 8)
                }
                Spacer()
            }
        }
        .onChange(of: apiBaseURL) { _, _ in
            webViewKey += 1
        }
    }
}

struct WebViewRepresentable: UIViewRepresentable {
    let apiBaseURL: String

    func makeCoordinator() -> Coordinator {
        Coordinator(apiBaseURL: apiBaseURL)
    }

    func makeUIView(context: Context) -> WKWebView {
        let prefs = WKWebpagePreferences()
        prefs.allowsContentJavaScript = true

        let config = WKWebViewConfiguration()
        config.defaultWebpagePreferences = prefs
        config.allowsInlineMediaPlayback = true

        let scriptSource = "window.__apiBaseURL__ = '\(apiBaseURL)';"
        let userScript = WKUserScript(
            source: scriptSource,
            injectionTime: .atDocumentStart,
            forMainFrameOnly: true
        )
        config.userContentController.addUserScript(userScript)

        let themeScript = """
        (function() {
            const prefersDark = window.matchMedia('(prefers-color-scheme: dark)').matches;
            window.__systemDarkMode__ = prefersDark;
        })();
        """
        let themeUserScript = WKUserScript(
            source: themeScript,
            injectionTime: .atDocumentStart,
            forMainFrameOnly: true
        )
        config.userContentController.addUserScript(themeUserScript)

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator
        webView.uiDelegate = context.coordinator
        webView.scrollView.contentInsetAdjustmentBehavior = .never
        webView.scrollView.bounces = true
        webView.allowsBackForwardNavigationGestures = false
        webView.isOpaque = false
        webView.backgroundColor = UIColor(red: 0.031, green: 0.043, blue: 0.078, alpha: 1.0)

        if let wwwURL = Bundle.main.url(forResource: "index", withExtension: "html", subdirectory: "www") {
            webView.loadFileURL(wwwURL, allowingReadAccessTo: wwwURL.deletingLastPathComponent())
        }

        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {}

    class Coordinator: NSObject, WKNavigationDelegate, WKUIDelegate {
        let apiBaseURL: String

        init(apiBaseURL: String) {
            self.apiBaseURL = apiBaseURL
        }

        func webView(
            _ webView: WKWebView,
            decidePolicyFor navigationAction: WKNavigationAction,
            decisionHandler: @escaping (WKNavigationActionPolicy) -> Void
        ) {
            guard let url = navigationAction.request.url else {
                decisionHandler(.cancel)
                return
            }

            if url.scheme == "file" || url.absoluteString.contains("localhost") || url.absoluteString.contains("127.0.0.1") {
                decisionHandler(.allow)
                return
            }

            if url.absoluteString.hasPrefix(apiBaseURL) {
                decisionHandler(.allow)
                return
            }

            if navigationAction.navigationType == .linkActivated {
                UIApplication.shared.open(url)
                decisionHandler(.cancel)
                return
            }

            decisionHandler(.allow)
        }

        func webView(
            _ webView: WKWebView,
            createWebViewWith configuration: WKWebViewConfiguration,
            for navigationAction: WKNavigationAction,
            windowFeatures: WKWindowFeatures
        ) -> WKWebView? {
            if let url = navigationAction.request.url {
                UIApplication.shared.open(url)
            }
            return nil
        }
    }
}