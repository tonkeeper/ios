import TKUIKit
import UIKit
import WebKit

public enum TKWebViewControllerNavigationHandlerResult {
    case open
    case notOpen
}

public protocol TKWebViewControllerNavigationHandler {
    func handlerURLOpen(_ url: URL) -> TKWebViewControllerNavigationHandlerResult
}

public final class TKWebViewController: UIViewController {
    private lazy var webView: WKWebView = {
        let configuration = WKWebViewConfiguration()
        configuration.allowsInlineMediaPlayback = true
        return WKWebView(frame: .zero, configuration: configuration)
    }()

    private let url: URL
    private let handler: TKWebViewControllerNavigationHandler

    public init(
        url: URL,
        handler: TKWebViewControllerNavigationHandler
    ) {
        self.url = url
        self.handler = handler
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override public func viewDidLoad() {
        super.viewDidLoad()
        view.addSubview(webView)
        view.backgroundColor = .Background.page
        webView.backgroundColor = .Background.page
        webView.scrollView.backgroundColor = .Background.page
        webView.load(URLRequest(url: url))
        webView.navigationDelegate = self
        webView.uiDelegate = self
        setupRightCloseButton { [weak self] in
            self?.dismiss(animated: true)
        }
    }

    override public func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        webView.frame = view.bounds
    }
}

extension TKWebViewController: WKNavigationDelegate {
    public func webView(
        _ webView: WKWebView,
        decidePolicyFor navigationAction: WKNavigationAction,
        decisionHandler: @escaping (WKNavigationActionPolicy) -> Void
    ) {
        if navigationAction.navigationType == .linkActivated {
            if let url = navigationAction.request.url {
                let result = handler.handlerURLOpen(url)
                switch result {
                case .open:
                    decisionHandler(.allow)
                case .notOpen:
                    decisionHandler(.cancel)
                }
            } else {
                decisionHandler(.allow)
            }
        } else {
            decisionHandler(.allow)
        }
    }
}

extension TKWebViewController: WKUIDelegate {
    public func webView(
        _ webView: WKWebView,
        runJavaScriptAlertPanelWithMessage message: String,
        initiatedByFrame frame: WKFrameInfo,
        completionHandler: @escaping () -> Void
    ) {
        let alert = UIAlertController(
            title: message,
            message: nil,
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(
            title: "OK",
            style: .default,
            handler: { _ in
                completionHandler()
            }
        ))
        present(alert, animated: true)
    }

    public func webView(
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
}
