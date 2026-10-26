import SnapKit
import TKLocalize
import TKLogging
import TKUIKit
import UIKit
import WebKit

open class TKBridgeWebViewController: UIViewController {
    public enum LoadFailure: Equatable {
        case network(domain: String, code: Int)
        case httpError(status: Int)
        case processTerminated
    }

    public struct Configuration {
        public let copyToastConfiguration: ToastPresenter.Configuration
        public let websiteDataStore: WKWebsiteDataStore?
        public let applicationNameForUserAgent: String?
        public let showsInitialLoadingIndicator: Bool
        public let allowsBackForwardNavigationGestures: Bool
        public init(
            copyToastConfiguration: ToastPresenter.Configuration,
            websiteDataStore: WKWebsiteDataStore? = nil,
            applicationNameForUserAgent: String? = nil,
            showsInitialLoadingIndicator: Bool = false,
            allowsBackForwardNavigationGestures: Bool = false
        ) {
            self.copyToastConfiguration = copyToastConfiguration
            self.websiteDataStore = websiteDataStore
            self.applicationNameForUserAgent = applicationNameForUserAgent
            self.showsInitialLoadingIndicator = showsInitialLoadingIndicator
            self.allowsBackForwardNavigationGestures = allowsBackForwardNavigationGestures
        }
    }

    public var isHeaderHidden = false {
        didSet {
            guard isViewLoaded else { return }
            navigationBar.isHidden = isHeaderHidden
            setupWebViewConstraints()
        }
    }

    public var didTapCopy: ((URL) -> Void)?
    public var didTapShare: ((URL) -> Void)?
    public var didTapClose: (() -> Void)?

    public var didLoadInitialURLHandler: (() -> Void)?

    public var didCommitLoad: ((URL) -> Void)?
    public var didFinishLoad: ((URL) -> Void)?
    public var didFailLoad: ((LoadFailure) -> Void)?
    public var didChangeCanGoBack: ((Bool) -> Void)?

    public var currentURL: URL? {
        webView.url
    }

    public var canGoBack: Bool {
        webView.canGoBack
    }

    private let userContentController = WKUserContentController()

    private lazy var webView: WKWebView = {
        let configuration = WKWebViewConfiguration()
        let script = WKUserScript(
            source: jsInjection,
            injectionTime: WKUserScriptInjectionTime.atDocumentStart,
            forMainFrameOnly: true
        )
        userContentController.addUserScript(script)
        if self.configuration.showsInitialLoadingIndicator {
            userContentController.addUserScript(
                WKUserScript(
                    source: Self.firstPaintScript,
                    injectionTime: .atDocumentStart,
                    forMainFrameOnly: true
                )
            )
        }
        configuration.userContentController = userContentController
        configuration.allowsInlineMediaPlayback = true
        if let websiteDataStore = self.configuration.websiteDataStore {
            configuration.websiteDataStore = websiteDataStore
        }
        if let applicationNameForUserAgent = self.configuration.applicationNameForUserAgent {
            configuration.applicationNameForUserAgent = applicationNameForUserAgent
        }
        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.allowsBackForwardNavigationGestures = self.configuration.allowsBackForwardNavigationGestures
        customizeWebView?(webView)
        return webView
    }()

    private let navigationBar = TKUINavigationBar()
    private var initialLoadingIndicator: TKLoaderView?
    private static let firstPaintMessageName = "tkBridgeFirstPaint"
    private static let firstPaintScript = """
    (function () {
        var report = function () {
            window.webkit.messageHandlers.\(TKBridgeWebViewController.firstPaintMessageName).postMessage('');
        };
        var schedule = function () {
            window.requestAnimationFrame(function () {
                window.requestAnimationFrame(report);
            });
        };
        if (document.readyState === 'loading') {
            document.addEventListener('DOMContentLoaded', schedule);
        } else {
            schedule();
        }
    })();
    """
    private let titleView = TKUINavigationBarTitleView()
    private lazy var backButton: TKUIHeaderIconButton = {
        let button = TKUINavigationBar.createBackButton { [weak self] in
            self?.backButtonAction()
        }
        button.setContentCompressionResistancePriority(.required, for: .horizontal)
        return button
    }()

    private lazy var rightPillButton: TKPillButton = {
        let button = TKPillButton()
        button.setContentCompressionResistancePriority(.required, for: .horizontal)

        button.configuration = TKPillButton.Configuration(
            leftButton: TKPillButton.Configuration.Button(
                icon: .TKUIKit.Icons.Size16.ellipses,
                action: { [weak self] in
                    self?.menuButtonAction()
                }
            ),
            rightButton: TKPillButton.Configuration.Button(
                icon: .TKUIKit.Icons.Size16.close,
                action: { [weak self] in
                    self?.closeButtonAction()
                }
            )
        )

        return button
    }()

    // MARK: - KVO

    private var canGoBackObservation: NSKeyValueObservation?

    // MARK: - State

    private var url: URL {
        didSet {
            guard url.host != oldValue.host else {
                return
            }
            title = webView.title
            didUpdateUrl()
        }
    }

    private var didLoadInitialURL = false {
        didSet {
            guard didLoadInitialURL else { return }
            didLoadInitialURLHandler?()
        }
    }

    private var bridgeMessageObservers = [String: [(Any) -> Void]]()

    // MARK: - Dependencies

    private let initialURL: URL
    private let copyURL: URL?
    private let initialTitle: String?
    private let jsInjection: String
    private let configuration: Configuration
    private let deeplinkHandler: ((_ deeplink: String) throws -> Void)?
    private let customizeWebView: ((WKWebView) -> Void)?

    // MARK: - Init

    public init(
        initialURL: URL,
        copyURL: URL? = nil,
        initialTitle: String?,
        jsInjection: String?,
        configuration: Configuration,
        deeplinkHandler: ((_ deeplink: String) throws -> Void)? = nil,
        customizeWebView: ((WKWebView) -> Void)? = nil
    ) {
        self.initialURL = initialURL
        self.copyURL = copyURL
        self.initialTitle = initialTitle
        self.url = initialURL
        self.configuration = configuration
        self.jsInjection = jsInjection ?? ""
        self.deeplinkHandler = deeplinkHandler
        self.customizeWebView = customizeWebView
        super.init(nibName: nil, bundle: nil)
        self.title = initialTitle
    }

    @available(*, unavailable)
    public required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - View Life Cycle

    override open func viewDidLoad() {
        super.viewDidLoad()

        navigationBar.centerView = titleView

        view.backgroundColor = .Background.page
        webView.backgroundColor = .Background.page
        webView.scrollView.backgroundColor = .Background.page
        webView.isOpaque = false
        webView.navigationDelegate = self
        webView.uiDelegate = self
        webView.scrollView.layer.masksToBounds = false
        webView.layer.masksToBounds = false
        #if DEBUG
            if #available(iOS 16.4, *) {
                webView.isInspectable = true
            }
        #endif

        view.addSubview(webView)
        if configuration.showsInitialLoadingIndicator {
            showInitialLoadingIndicator()
        }
        view.addSubview(navigationBar)

        navigationBar.isHidden = isHeaderHidden

        setupConstraints()

        didUpdateUrl()

        navigationBar.leftViews = [backButton]
        rightPillButton.rightButtonAccessibilityIdentifier = "close"
        navigationBar.rightViews = [rightPillButton]

        backButton.isHidden = true
        canGoBackObservation = webView.observe(\.canGoBack, options: .new) { [weak self] _, value in
            guard let canGoBack = value.newValue else { return }
            self?.backButton.isHidden = !canGoBack
            self?.didChangeCanGoBack?(canGoBack)
        }

        let urlRequest = URLRequest(url: updateURLWithTonkeeperUTM(url: url))
        webView.load(urlRequest)
    }

    public func evaulateJavaScript(_ javaScript: String) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Swift.Error>) in
            webView.evaluateJavaScript(javaScript) { _, error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume()
                }
            }
        }
    }

    public func addBridgeMessageObserver(message: String, observer: @escaping (Any) -> Void) {
        if var messageObservers = bridgeMessageObservers[message] {
            messageObservers.append(observer)
            bridgeMessageObservers[message] = messageObservers
        } else {
            userContentController.add(WeakScriptMessageHandler(delegate: self), name: message)
            bridgeMessageObservers[message] = [observer]
        }
    }

    private func setupConstraints() {
        navigationBar.snp.makeConstraints { make in
            make.top.left.right.equalTo(self.view)
        }
        setupWebViewConstraints()
    }

    private func setupWebViewConstraints() {
        webView.snp.remakeConstraints { make in
            if isHeaderHidden {
                make.top.equalTo(view)
            } else {
                make.top.equalTo(navigationBar.snp.bottom)
            }
            make.left.right.equalTo(self.view)
            make.bottom.equalTo(self.view.snp.bottom)
        }
    }

    private func showInitialLoadingIndicator() {
        let loaderView = TKLoaderView(size: .medium, style: .primary)
        view.addSubview(loaderView)
        loaderView.snp.makeConstraints { make in
            make.center.equalTo(webView)
        }
        loaderView.isLoading = true
        initialLoadingIndicator = loaderView
        addBridgeMessageObserver(message: Self.firstPaintMessageName) { [weak self] _ in
            self?.hideInitialLoadingIndicator()
        }
    }

    private func hideInitialLoadingIndicator() {
        guard let initialLoadingIndicator else { return }
        initialLoadingIndicator.isLoading = false
        initialLoadingIndicator.removeFromSuperview()
        self.initialLoadingIndicator = nil
    }

    private func backButtonAction() {
        webView.goBack()
    }

    private func closeButtonAction() {
        webView.scrollView.layer.masksToBounds = true
        webView.layer.masksToBounds = true
        if let didTapClose {
            didTapClose()
        } else {
            dismiss(animated: true)
        }
    }

    private func menuButtonAction() {
        let items = [
            TKPopupMenuItem(
                title: TKLocales.BridgeWeb.refresh,
                icon: .TKUIKit.Icons.Size16.refresh,
                selectionHandler: { [weak self] in
                    self?.webView.reload()
                }
            ),
            TKPopupMenuItem(
                title: TKLocales.BridgeWeb.share,
                icon: .TKUIKit.Icons.Size16.share,
                selectionHandler: { [weak self] in
                    guard let url = self?.copyURL ?? self?.webView.url else { return }
                    if let didTapShare = self?.didTapShare {
                        didTapShare(url)
                    } else {
                        self?.shareURL(url: url)
                    }
                }
            ),
            TKPopupMenuItem(
                title: TKLocales.BridgeWeb.copyLink,
                icon: .TKUIKit.Icons.Size16.copy,
                selectionHandler: { [weak self, configuration] in
                    guard let url = self?.copyURL ?? self?.webView.url else { return }
                    if let didTapCopy = self?.didTapCopy {
                        didTapCopy(url)
                    } else {
                        ToastPresenter.showToast(configuration: configuration.copyToastConfiguration)
                        UIPasteboard.general.string = url.absoluteString
                    }
                }
            ),
        ]
        TKPopupMenuController.show(
            sourceView: rightPillButton,
            position: .bottomRight(inset: 8),
            minimumWidth: 0,
            items: items,
            isSelectable: false,
            selectedIndex: nil
        )
    }

    private func shareURL(url: URL) {
        let activityViewController = UIActivityViewController(
            activityItems: [url as Any],
            applicationActivities: nil
        )
        present(
            activityViewController,
            animated: true
        )
    }

    private func updateURLWithTonkeeperUTM(url: URL) -> URL {
        guard var urlComponents = URLComponents(url: url, resolvingAgainstBaseURL: false) else { return url }
        var queryItems = urlComponents.queryItems ?? []
        guard !queryItems.contains(where: { $0.name != "utm_source" }) else { return url }
        queryItems.append(URLQueryItem(name: "utm_source", value: "tonkeeper"))
        urlComponents.queryItems = queryItems
        guard let updatedURL = urlComponents.url else { return url }
        return updatedURL
    }

    private func didUpdateUrl() {
        func update(title: String?, caption: String, isSecure: Bool) {
            titleView.configure(model: .webPage(title: title, host: caption, isSecure: isSecure))
        }

        if let serverTrust = webView.serverTrust {
            SecTrustEvaluateAsyncWithError(serverTrust, .main) { _, isSecured, _ in
                let caption = self.url.host ?? ""
                update(title: self.title, caption: caption, isSecure: isSecured)
            }
        } else {
            let components = URLComponents(string: url.absoluteString)
            let isSecured = components?.scheme == "https"
            let caption = url.host ?? ""
            update(title: self.title, caption: caption, isSecure: isSecured)
        }
    }
}

extension TKBridgeWebViewController: WKNavigationDelegate {
    public func webView(_ webView: WKWebView, didCommit navigation: WKNavigation!) {
        guard let url = webView.url else { return }
        didCommitLoad?(url)
    }

    public func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        hideInitialLoadingIndicator()
        guard let url = webView.url else { return }
        if !didLoadInitialURL {
            didLoadInitialURL = true
        }
        self.url = url
        didFinishLoad?(url)
    }

    public func webView(
        _ webView: WKWebView,
        didFailProvisionalNavigation navigation: WKNavigation!,
        withError error: Error
    ) {
        handleNavigationError(error)
    }

    public func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        handleNavigationError(error)
    }

    public func webView(
        _ webView: WKWebView,
        decidePolicyFor navigationResponse: WKNavigationResponse
    ) async -> WKNavigationResponsePolicy {
        if navigationResponse.isForMainFrame,
           let response = navigationResponse.response as? HTTPURLResponse,
           response.statusCode >= 400
        {
            handleLoadFailure(.httpError(status: response.statusCode))
        }
        return .allow
    }

    public func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
        handleLoadFailure(.processTerminated)
    }

    private func handleNavigationError(_ error: Error) {
        let error = error as NSError
        guard error.code != NSURLErrorCancelled else { return }
        handleLoadFailure(.network(domain: error.domain, code: error.code))
    }

    private func handleLoadFailure(_ failure: LoadFailure) {
        hideInitialLoadingIndicator()
        didFailLoad?(failure)
    }

    public func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction) async -> WKNavigationActionPolicy {
        guard let url = navigationAction.request.url else { return .allow }
        return navigationPolicy(for: url)
    }

    private func navigationPolicy(for url: URL) -> WKNavigationActionPolicy {
        let externalOpenHosts = ["t.me"]
        let externalOpenUrlSchemes = ["tg"]
        if let scheme = url.scheme, externalOpenUrlSchemes.contains(scheme), UIApplication.shared.canOpenURL(url) {
            UIApplication.shared.open(url, options: [:], completionHandler: nil)
            return .cancel
        }
        if let host = url.host, externalOpenHosts.contains(host) {
            UIApplication.shared.open(url, options: [:], completionHandler: nil)
            return .cancel
        }
        if let handler = deeplinkHandler {
            do {
                try handler(url.absoluteString)
                return .cancel
            } catch {
                return .allow
            }
        }
        return .allow
    }
}

extension TKBridgeWebViewController: WKUIDelegate {
    public func webView(
        _ webView: WKWebView,
        createWebViewWith configuration: WKWebViewConfiguration,
        for navigationAction: WKNavigationAction,
        windowFeatures: WKWindowFeatures
    ) -> WKWebView? {
        guard navigationAction.targetFrame == nil else { return nil }
        // A sized window.open is a popup, e.g. Telegram Login: it hands its result back through
        // window.opener, so it gets a web view of its own instead of replacing the opener's page.
        guard windowFeatures.width != nil || windowFeatures.height != nil else {
            webView.load(navigationAction.request)
            return nil
        }
        if let url = navigationAction.request.url, navigationPolicy(for: url) == .cancel {
            return nil
        }
        configuration.userContentController = WKUserContentController()
        let popupWebView = WKWebView(frame: .zero, configuration: configuration)
        let sourceHost = navigationAction.sourceFrame.securityOrigin.host
        let popupViewController = TKBridgeWebPopupViewController(
            webView: popupWebView,
            openerHost: sourceHost.isEmpty ? webView.url?.host ?? "" : sourceHost,
            navigationPolicy: { [weak self] url in
                self?.navigationPolicy(for: url) ?? .allow
            }
        )
        present(popupViewController, animated: true)
        return popupWebView
    }
}

extension TKUINavigationBarTitleView.Model {
    static func webPage(title: String?, host: String, isSecure: Bool) -> TKUINavigationBarTitleView.Model {
        var icon: TKPlainButton.Model.Icon?
        if isSecure {
            icon = TKPlainButton.Model.Icon(
                image: .TKUIKit.Icons.Size12.lock,
                tintColor: .Text.secondary,
                padding: UIEdgeInsets(top: 5, left: 0, bottom: 3, right: 4),
                iconPosition: .left
            )
        }

        let caption = TKPlainButton.Model(
            title: host.withTextStyle(
                .body2,
                color: .Text.secondary,
                alignment: .center,
                lineBreakMode: .byTruncatingTail
            ),
            icon: icon,
            action: nil
        )

        return TKUINavigationBarTitleView.Model(
            title: title,
            caption: caption
        )
    }
}

extension TKBridgeWebViewController: WKScriptMessageHandler {
    public func userContentController(
        _ userContentController: WKUserContentController,
        didReceive message: WKScriptMessage
    ) {
        guard isMessageFromTrustedFrame(message) else {
            Log.w("bridge: rejected non-main-frame message name=\(message.name)")
            return
        }
        let observers = bridgeMessageObservers[message.name]
        observers?.forEach { $0(message.body) }
    }

    private func isMessageFromTrustedFrame(_ message: WKScriptMessage) -> Bool {
        guard message.frameInfo.isMainFrame else { return false }
        if let frameHost = message.frameInfo.request.url?.host,
           let webViewHost = webView.url?.host,
           frameHost != webViewHost
        {
            return false
        }
        return true
    }
}

private final class WeakScriptMessageHandler: NSObject, WKScriptMessageHandler {
    private weak var delegate: WKScriptMessageHandler?

    init(delegate: WKScriptMessageHandler) {
        self.delegate = delegate
    }

    func userContentController(
        _ userContentController: WKUserContentController,
        didReceive message: WKScriptMessage
    ) {
        delegate?.userContentController(userContentController, didReceive: message)
    }
}
