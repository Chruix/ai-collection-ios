import SwiftUI
import WebKit

// MARK: - WebView Container

struct WebViewContainer: View {
    let apiBaseURL: String
    @Binding var intentSection: String?
    @Binding var intentSearchQuery: String?
    @Binding var showSettings: Bool
    @State private var webViewKey = 0
    @State private var webView: WKWebView?

    var body: some View {
        ZStack(alignment: .topTrailing) {
            WebViewRepresentable(apiBaseURL: apiBaseURL, webView: $webView)
                .id(webViewKey)
                .ignoresSafeArea()

            SettingsButton(action: { showSettings = true })
        }
        .onChange(of: apiBaseURL) { _, _ in
            webViewKey += 1
        }
        .onChange(of: intentSection) { _, newValue in
            guard let section = newValue else { return }
            intentSection = nil
            navigateWebView(to: section, query: nil)
        }
        .onChange(of: intentSearchQuery) { _, newValue in
            guard let query = newValue else { return }
            intentSearchQuery = nil
            navigateWebView(to: "search", query: query)
        }
    }

    private func navigateWebView(to section: String, query: String?) {
        guard let wv = webView else { return }
        let js: String
        if let q = query {
            let escaped = q
                .replacingOccurrences(of: "\\", with: "\\\\")
                .replacingOccurrences(of: "'", with: "\\'")
                .replacingOccurrences(of: "\n", with: "\\n")
            js = "showTab('\(section)');setTimeout(function(){var si=document.getElementById('searchInput');if(si){si.value='\(escaped)';si.dispatchEvent(new Event('input'));}},400);"
        } else {
            js = "showTab('\(section)');"
        }
        wv.evaluateJavaScript(js)
    }
}

// MARK: - Settings Button

private struct SettingsButton: View {
    let action: () -> Void

    var body: some View {
        VStack {
            HStack {
                Spacer()
                Button(action: action) {
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
}

// MARK: - WebView Representable

struct WebViewRepresentable: UIViewRepresentable {
    let apiBaseURL: String
    @Binding var webView: WKWebView?

    func makeCoordinator() -> Coordinator {
        Coordinator(apiBaseURL: apiBaseURL)
    }

    func makeUIView(context: Context) -> WKWebView {
        let config = webViewConfiguration()
        injectStartupScripts(into: config.userContentController)
        injectBridgeScript(into: config.userContentController)

        let wv = WKWebView(frame: .zero, configuration: config)
        wv.navigationDelegate = context.coordinator
        wv.uiDelegate = context.coordinator
        wv.scrollView.contentInsetAdjustmentBehavior = .never
        wv.scrollView.bounces = true
        wv.allowsBackForwardNavigationGestures = false
        wv.isOpaque = false
        wv.backgroundColor = UIColor(red: 0.031, green: 0.043, blue: 0.078, alpha: 1.0)

        // 挂载 native fetch 消息处理（此前从未接线，网页抓取功能实际不可用）
        let handler = NativeFetchMessageHandler(webView: wv)
        context.coordinator.nativeFetchHandler = handler

        loadLocalContent(into: wv)

        DispatchQueue.main.async {
            self.webView = wv
        }

        return wv
    }

    func updateUIView(_ webView: WKWebView, context: Context) {}

    // MARK: Configuration Helpers

    private func webViewConfiguration() -> WKWebViewConfiguration {
        let prefs = WKWebpagePreferences()
        prefs.allowsContentJavaScript = true

        let config = WKWebViewConfiguration()
        config.defaultWebpagePreferences = prefs
        config.allowsInlineMediaPlayback = true

        return config
    }

    private func injectStartupScripts(into controller: WKUserContentController) {
        let apiScript = WKUserScript(
            source: "window.__apiBaseURL__ = '" + apiBaseURL + "';",
            injectionTime: .atDocumentStart,
            forMainFrameOnly: true
        )
        controller.addUserScript(apiScript)

        let themeScript = WKUserScript(
            source: """
            (function() {
                const prefersDark = window.matchMedia("(prefers-color-scheme: dark)").matches;
                window.__systemDarkMode__ = prefersDark;
            })();
            """,
            injectionTime: .atDocumentStart,
            forMainFrameOnly: true
        )
        controller.addUserScript(themeScript)
    }

    private func loadLocalContent(into webView: WKWebView) {
        guard let wwwURL = Bundle.main.url(
            forResource: "index",
            withExtension: "html",
            subdirectory: "www"
        ) else { return }
        webView.loadFileURL(wwwURL, allowingReadAccessTo: wwwURL.deletingLastPathComponent())
    }

    // MARK: Coordinator

    
// MARK: - Native Message Bridge for URL Fetching

private func injectBridgeScript(into controller: WKUserContentController) {
    let bridgeJS = """
    window.__nativeFetch__ = function(url) {
        return new Promise(function(resolve, reject) {
            var id = 'nf_' + Date.now() + '_' + Math.random().toString(36).slice(2);
            window.__nativeFetchCallbacks__ = window.__nativeFetchCallbacks__ || {};
            window.__nativeFetchCallbacks__[id] = { resolve: resolve, reject: reject };
            try {
                window.webkit.messageHandlers.nativeFetch.postMessage({ id: id, url: url });
            } catch(e) {
                delete window.__nativeFetchCallbacks__[id];
                reject(e);
            }
        });
    };
    """
    let script = WKUserScript(source: bridgeJS, injectionTime: .atDocumentStart, forMainFrameOnly: true)
    controller.addUserScript(script)
}

    class Coordinator: NSObject, WKNavigationDelegate, WKUIDelegate {
        let apiBaseURL: String
        // 持有 native fetch handler，避免被释放后 WebView 消息无人接收
        fileprivate var nativeFetchHandler: NativeFetchMessageHandler?

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

            let isLocal = url.scheme == "file"
                || url.absoluteString.contains("localhost")
                || url.absoluteString.contains("127.0.0.1")

            let isAPI = url.absoluteString.hasPrefix(apiBaseURL)

            if isLocal || isAPI {
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



private class NativeFetchMessageHandler: NSObject, WKScriptMessageHandler {
    weak var webView: WKWebView?

    init(webView: WKWebView) {
        self.webView = webView
        super.init()
        // WKWebView 的 userContentController 在配置时共享同一实例，此处注册生效
        webView.configuration.userContentController.add(self, name: "nativeFetch")
    }

    deinit {
        webView?.configuration.userContentController.removeScriptMessageHandler(forName: "nativeFetch")
    }

    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        guard let body = message.body as? [String: Any],
              let id = body["id"] as? String,
              let urlStr = body["url"] as? String,
              var url = URL(string: urlStr) else {
            return
        }

        if !urlStr.hasPrefix("http") {
            url = URL(string: "https://" + urlStr) ?? url
        }

        var request = URLRequest(url: url)
        request.setValue("Mozilla/5.0 (Linux; Android 14) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36", forHTTPHeaderField: "User-Agent")

        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            guard let self = self, let wv = self.webView else { return }
            var resultJS: String
            if let error = error {
                let msg = error.localizedDescription.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "'", with: "\\'")
                resultJS = "window.__nativeFetchCallbacks__['\(id)'].reject(new Error('\(msg)')); delete window.__nativeFetchCallbacks__['\(id)'];"
            } else if let data = data, let html = String(data: data, encoding: .utf8) {
                let escaped = html.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "'", with: "\\'").replacingOccurrences(of: "\n", with: "\\n")
                let finalURL = (response as? HTTPURLResponse)?.url?.absoluteString ?? urlStr
                let fURL = finalURL.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "'", with: "\\'")
                resultJS = "window.__nativeFetchCallbacks__['\(id)'].resolve({html:'\(escaped)',url:'\(fURL)'}); delete window.__nativeFetchCallbacks__['\(id)'];"
            } else {
                resultJS = "window.__nativeFetchCallbacks__['\(id)'].reject(new Error('Empty response')); delete window.__nativeFetchCallbacks__['\(id)'];"
            }
            DispatchQueue.main.async {
                wv.evaluateJavaScript(resultJS)
            }
        }.resume()
    }
}
