import TKLogging
import UIKit
import WebKit

/// Hosts one MoonPay frame in a `WKWebView`: loads the frame URL, exposes the `MoonPayBridge`
/// script, answers the handshake, and hands decoded events to `didReceiveEvent`.
///
/// Present co-branded frames (`connect`, `widget`, `add-card`, `challenge`) full screen; embed
/// headless ones (`check-connection`, `buy`, `apple-pay`) as a child view controller.
@MainActor
public final class MoonPayFrameViewController: UIViewController {
    public let moonPayFrame: MoonPayFrame
    public let environment: MoonPayEnvironment
    public let channelId: String

    public var didReceiveEvent: ((MoonPayFrameEvent) -> Void)?
    public var didFailToLoad: ((MoonPayFrameError) -> Void)?
    /// Low-level trace for debugging a frame: navigations, popup requests, and messages that were
    /// dropped before becoming an event (untrusted origin, foreign channel, malformed body).
    public var didReportDiagnostic: ((String) -> Void)?

    private let bridge: MoonPayFrameBridge
    private let webView: WKWebView

    public init(
        frame moonPayFrame: MoonPayFrame,
        environment: MoonPayEnvironment,
        channelId: String = UUID().uuidString.lowercased()
    ) {
        self.moonPayFrame = moonPayFrame
        self.environment = environment
        self.channelId = channelId
        bridge = MoonPayFrameBridge(channelId: channelId, environment: environment)
        webView = Self.makeWebView()
        super.init(nibName: nil, bundle: nil)
        webView.configuration.userContentController.add(
            WeakScriptMessageProxy(target: self),
            name: MoonPayFrameBridge.messageHandlerName
        )
        webView.uiDelegate = self
        webView.navigationDelegate = self
    }

    @available(*, unavailable)
    public required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override public func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        webView.isOpaque = false
        webView.backgroundColor = .clear
        webView.scrollView.backgroundColor = .clear
        webView.frame = view.bounds
        webView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(webView)
        load()
    }

    public func reload() {
        load()
    }

    public func send(_ command: MoonPayFrameCommand) {
        let script: String
        do {
            script = try command.message(channelId: channelId).javaScriptPostMessageStatement()
        } catch {
            Log.e("MoonPay frame \(moonPayFrame.name): cannot encode \(command.kind)", error: error)
            return
        }
        webView.evaluateJavaScript(script) { [weak self, moonPayFrame] _, error in
            if let error {
                Log.w("MoonPay frame \(moonPayFrame.name): \(command.kind) was not delivered", error: error)
                self?.didReportDiagnostic?("\(command.kind) was not delivered: \(error.localizedDescription)")
            }
        }
    }

    private func load() {
        do {
            let url = try moonPayFrame.url(environment: environment, channelId: channelId)
            webView.load(URLRequest(url: url))
        } catch let error as MoonPayFrameError {
            didFailToLoad?(error)
        } catch {
            didFailToLoad?(.invalidURL)
        }
    }

    private static func makeWebView() -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.allowsInlineMediaPlayback = true
        configuration.mediaTypesRequiringUserActionForPlayback = []
        let contentController = WKUserContentController()
        contentController.addUserScript(
            WKUserScript(
                source: MoonPayFrameBridge.userScriptSource,
                injectionTime: .atDocumentStart,
                forMainFrameOnly: false
            )
        )
        configuration.userContentController = contentController
        let webView = WKWebView(frame: .zero, configuration: configuration)
        #if DEBUG
            if #available(iOS 16.4, *) {
                webView.isInspectable = true
            }
        #endif
        return webView
    }

    private func presentAlert(_ alert: UIAlertController, otherwise fallback: () -> Void) {
        guard viewIfLoaded?.window != nil else {
            fallback()
            return
        }
        present(alert, animated: true)
    }
}

extension MoonPayFrameViewController: WKScriptMessageHandler {
    public func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        guard message.name == MoonPayFrameBridge.messageHandlerName else { return }
        let origin = message.frameInfo.securityOrigin
        guard bridge.isTrustedOrigin(scheme: origin.protocol, host: origin.host) else {
            Log.w("MoonPay frame \(moonPayFrame.name): rejected message from \(origin.protocol)://\(origin.host)")
            didReportDiagnostic?("rejected message from \(origin.protocol)://\(origin.host)")
            return
        }
        switch bridge.receive(body: message.body) {
        case let .event(event):
            if case .handshake = event {
                send(.ack)
            }
            if !message.frameInfo.isMainFrame {
                didReportDiagnostic?("\(event.name) posted from a nested frame at \(message.frameInfo.request.url?.host ?? "?")")
            }
            didReceiveEvent?(event)
        case let .foreignChannel(channel):
            Log.d("MoonPay frame \(moonPayFrame.name): ignored message for channel \(channel)")
            didReportDiagnostic?("ignored message for channel \(channel) (ours: \(channelId))")
        case let .malformed(reason):
            Log.w("MoonPay frame \(moonPayFrame.name): ignored malformed message: \(reason)")
            didReportDiagnostic?("ignored malformed message: \(reason)")
        }
    }
}

extension MoonPayFrameViewController: WKUIDelegate {
    public func webView(
        _ webView: WKWebView,
        runJavaScriptAlertPanelWithMessage message: String,
        initiatedByFrame frame: WKFrameInfo,
        completionHandler: @escaping () -> Void
    ) {
        let alert = UIAlertController(title: nil, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default) { _ in completionHandler() })
        presentAlert(alert, otherwise: completionHandler)
    }

    /// Test-mode Apple Pay confirms through `window.confirm`; WebKit's default answer is `false`,
    /// which silently fails every test payment.
    public func webView(
        _ webView: WKWebView,
        runJavaScriptConfirmPanelWithMessage message: String,
        initiatedByFrame frame: WKFrameInfo,
        completionHandler: @escaping (Bool) -> Void
    ) {
        let alert = UIAlertController(title: nil, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel) { _ in completionHandler(false) })
        alert.addAction(UIAlertAction(title: "OK", style: .default) { _ in completionHandler(true) })
        presentAlert(alert) { completionHandler(false) }
    }

    public func webView(
        _ webView: WKWebView,
        runJavaScriptTextInputPanelWithPrompt prompt: String,
        defaultText: String?,
        initiatedByFrame frame: WKFrameInfo,
        completionHandler: @escaping (String?) -> Void
    ) {
        let alert = UIAlertController(title: nil, message: prompt, preferredStyle: .alert)
        alert.addTextField { $0.text = defaultText }
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel) { _ in completionHandler(nil) })
        alert.addAction(UIAlertAction(title: "OK", style: .default) { [weak alert] _ in
            completionHandler(alert?.textFields?.first?.text)
        })
        presentAlert(alert) { completionHandler(nil) }
    }

    /// Identity verification captures documents and a selfie inside the frame.
    public func webView(
        _ webView: WKWebView,
        requestMediaCapturePermissionFor origin: WKSecurityOrigin,
        initiatedByFrame frame: WKFrameInfo,
        type: WKMediaCaptureType,
        decisionHandler: @escaping (WKPermissionDecision) -> Void
    ) {
        decisionHandler(bridge.isTrustedOrigin(scheme: origin.protocol, host: origin.host) ? .grant : .deny)
    }

    public func webView(
        _ webView: WKWebView,
        createWebViewWith configuration: WKWebViewConfiguration,
        for navigationAction: WKNavigationAction,
        windowFeatures: WKWindowFeatures
    ) -> WKWebView? {
        if navigationAction.targetFrame == nil {
            didReportDiagnostic?("popup requested for \(Self.describe(navigationAction.request.url)), loading inline")
            webView.load(navigationAction.request)
        }
        return nil
    }
}

extension MoonPayFrameViewController: WKNavigationDelegate {
    public func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        didReportDiagnostic?("loading \(Self.describe(webView.url))")
    }

    public func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        didReportDiagnostic?("loaded \(Self.describe(webView.url))")
    }

    public func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        report(error)
    }

    public func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        report(error)
    }

    public func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
        didFailToLoad?(.loadFailed("web content process terminated"))
    }

    private static func describe(_ url: URL?) -> String {
        guard let url else { return "?" }
        return "\(url.host ?? "")\(url.path)"
    }

    private func report(_ error: Error) {
        let nsError = error as NSError
        // A navigation replaced by another one reports NSURLErrorCancelled; nothing failed.
        if nsError.domain == NSURLErrorDomain, nsError.code == NSURLErrorCancelled {
            return
        }
        didFailToLoad?(.loadFailed(error.localizedDescription))
    }
}
