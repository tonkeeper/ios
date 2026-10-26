import SnapKit
import TKUIKit
import UIKit
import WebKit

final class TKBridgeWebPopupViewController: UIViewController {
    private let webView: WKWebView
    private let openerHost: String
    private let navigationPolicy: (URL) -> WKNavigationActionPolicy

    private let navigationBar = TKUINavigationBar()
    private let titleView = TKUINavigationBarTitleView()
    private var titleObservations = [NSKeyValueObservation]()

    init(webView: WKWebView, openerHost: String, navigationPolicy: @escaping (URL) -> WKNavigationActionPolicy) {
        self.webView = webView
        self.openerHost = openerHost
        self.navigationPolicy = navigationPolicy
        super.init(nibName: nil, bundle: nil)
        // WebKit starts loading the popup as soon as it gets the web view back, before this view loads.
        webView.navigationDelegate = self
        webView.uiDelegate = self
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        view.backgroundColor = .Background.page
        webView.backgroundColor = .Background.page
        webView.scrollView.backgroundColor = .Background.page
        webView.isOpaque = false
        #if DEBUG
            if #available(iOS 16.4, *) {
                webView.isInspectable = true
            }
        #endif

        view.addSubview(webView)
        view.addSubview(navigationBar)

        navigationBar.centerView = titleView
        navigationBar.rightViews = [
            TKUINavigationBar.createCloseButton { [weak self] in
                self?.dismiss(animated: true)
            },
        ]

        navigationBar.snp.makeConstraints { make in
            make.top.left.right.equalTo(view)
        }
        webView.snp.makeConstraints { make in
            make.top.equalTo(navigationBar.snp.bottom)
            make.left.right.bottom.equalTo(view)
        }

        titleObservations = [
            webView.observe(\.title, options: .initial) { [weak self] _, _ in
                self?.updateTitle()
            },
            webView.observe(\.url) { [weak self] _, _ in
                self?.updateTitle()
            },
        ]
    }

    private func updateTitle() {
        titleView.configure(model: .webPage(
            title: webView.title,
            host: contentHost,
            isSecure: webView.url?.scheme == "https"
        ))
    }

    /// A page without a host still has to name a site in the header, or the opener could fill a
    /// blank popup with a screen that passes for a native one. A blank document belongs to the frame
    /// that opened the window; a blob: URL carries the origin that created it.
    private var contentHost: String {
        guard let url = webView.url, url.scheme != "about" else { return openerHost }
        if url.scheme == "blob" {
            return URL(string: String(url.absoluteString.dropFirst("blob:".count)))?.host ?? "blob:"
        }
        return url.host ?? "\(url.scheme ?? ""):"
    }
}

extension TKBridgeWebPopupViewController: WKNavigationDelegate {
    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction) async -> WKNavigationActionPolicy {
        guard let url = navigationAction.request.url else { return .allow }
        return navigationPolicy(url)
    }
}

extension TKBridgeWebPopupViewController: WKUIDelegate {
    func webView(
        _ webView: WKWebView,
        createWebViewWith configuration: WKWebViewConfiguration,
        for navigationAction: WKNavigationAction,
        windowFeatures: WKWindowFeatures
    ) -> WKWebView? {
        if navigationAction.targetFrame == nil {
            webView.load(navigationAction.request)
        }
        return nil
    }

    func webViewDidClose(_ webView: WKWebView) {
        dismiss(animated: true)
    }
}
