import UIKit
import TKUIKit
import SnapKit
import WebKit

open class TKBridgeWebViewController: UIViewController {
  
  public var isHeaderHidden = false {
    didSet {
      setupWebViewConstraints()
      headerView.isHidden = isHeaderHidden
    }
  }
  
  public var didLoadInitialURLHandler: (() -> Void)?
  private let userContentController = WKUserContentController()
  
  private let jsInjection: String

  private lazy var webView: WKWebView = {
    let configuration = WKWebViewConfiguration()
    let script = WKUserScript(
      source: jsInjection,
      injectionTime: WKUserScriptInjectionTime.atDocumentStart,
      forMainFrameOnly: true
    )
    userContentController.addUserScript(script)
    configuration.userContentController = userContentController
    let webView = WKWebView(frame: .zero, configuration: configuration)
    return webView
  }()
  
  private let headerView = TKBridgeWebHeaderView()
  
  // MARK: - KVO
  
  private var canGoBack: NSKeyValueObservation?
  
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
  private let initialTitle: String?
  
  // MARK: - Init
  
  public init(initialURL: URL,
              initialTitle: String?,
              jsInjection: String?) {
    self.initialURL = initialURL
    self.initialTitle = initialTitle
    self.url = initialURL
    self.jsInjection = jsInjection ?? ""
    super.init(nibName: nil, bundle: nil)
    self.title = initialTitle
  }
  
  public required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  // MARK: - View Life Cycle
  
  open override func viewDidLoad() {
    super.viewDidLoad()
    
    view.backgroundColor = .Background.page
    webView.backgroundColor = .Background.page
    webView.scrollView.backgroundColor = .Background.page
    webView.isOpaque = false
    webView.navigationDelegate = self
    webView.uiDelegate = self
    webView.scrollView.layer.masksToBounds = false
    webView.layer.masksToBounds = false
    webView.scrollView.contentInsetAdjustmentBehavior = .never
#if DEBUG
    if #available(iOS 16.4, *) {
      webView.isInspectable = true
    }
#endif
    
    view.addSubview(webView)
    view.addSubview(headerView)
    
    headerView.isHidden = isHeaderHidden
    
    setupConstraints()
    
    didUpdateUrl()
    
    headerView.closeButton.configuration.action = { [weak self] in
      self?.webView.scrollView.layer.masksToBounds = true
      self?.webView.layer.masksToBounds = true
      self?.dismiss(animated: true)
    }
    headerView.backButton.configuration.action = { [weak self] in
      self?.webView.goBack()
    }
    
    headerView.backButton.isHidden = true
    canGoBack = webView.observe(\.canGoBack, options: .new) { [weak self] _, value in
      guard let canGoBack = value.newValue else { return }
      self?.headerView.backButton.isHidden = !canGoBack
    }
  
    var urlRequest = URLRequest(url: url)
    urlRequest.httpShouldHandleCookies = false
    urlRequest.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData
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
      userContentController.add(self, name: message)
      bridgeMessageObservers[message] = [observer]
    }
  }
  
  private func setupConstraints() {
    headerView.snp.makeConstraints { make in
      make.top.left.right.equalTo(self.view)
    }
    setupWebViewConstraints()
  }
  
  private func setupWebViewConstraints() {
    webView.snp.remakeConstraints { make in
      if isHeaderHidden {
        make.top.equalTo(view)
      } else {
        make.top.equalTo(headerView.snp.bottom)
      }
      make.left.right.equalTo(self.view)
      make.bottom.equalTo(self.view.snp.bottom)
    }
  }
  
  private func didUpdateUrl() {
    headerView.setTitle(title)
    if let serverTrust = webView.serverTrust {
      SecTrustEvaluateAsyncWithError(serverTrust, .main) { _, isSecured, _ in
        self.headerView.setSubtitle(self.url.host ?? "", isSecured: isSecured)
      }
    } else {
      let components = URLComponents(string: url.absoluteString)
      let isSecured = components?.scheme == "https"
      self.headerView.setSubtitle(url.host ?? "", isSecured: isSecured)
    }
  }
}

extension TKBridgeWebViewController: WKNavigationDelegate {
  public func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
    guard let url = webView.url else { return }
    if !didLoadInitialURL {
      didLoadInitialURL = true
    }
    self.url = url
  }
  
  public func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction) async -> WKNavigationActionPolicy {
    if let url = navigationAction.request.url, let host = url.host,host.contains("t.me") {
      UIApplication.shared.open(url, options: [:], completionHandler: nil)
      return .cancel
    }
    return .allow
  }
}

extension TKBridgeWebViewController: WKUIDelegate {
  public func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration, for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
    if navigationAction.targetFrame == nil {
      webView.load(navigationAction.request)
    }
    return nil
  }
}

extension TKBridgeWebViewController: WKScriptMessageHandler {
  public func userContentController(_ userContentController: WKUserContentController, 
                                    didReceive message: WKScriptMessage) {
    let observers = bridgeMessageObservers[message.name]
    observers?.forEach { $0(message.body) }
  }
}
