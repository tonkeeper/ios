import UIKit
import TKUIKit
import SnapKit
import WebKit

open class TKBridgeWebViewController: UIViewController {
  
  public struct Configuration {
    public let copyToastConfiguration: ToastPresenter.Configuration
    public init(copyToastConfiguration: ToastPresenter.Configuration) {
      self.copyToastConfiguration = copyToastConfiguration
    }
  }
  
  public var isHeaderHidden = false {
    didSet {
      setupWebViewConstraints()
      navigationBar.isHidden = isHeaderHidden
    }
  }
  
  public var didLoadInitialURLHandler: (() -> Void)?
  private let userContentController = WKUserContentController()
  
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
  
  private let navigationBar = TKUINavigationBar()
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
  private var webViewObserver: NSKeyValueObservation?

  // MARK: - Dependencies
  
  private let initialURL: URL
  private let initialTitle: String?
  private let jsInjection: String
  private let configuration: Configuration
  
  // MARK: - Init
  
  public init(initialURL: URL,
              initialTitle: String?,
              jsInjection: String?,
              configuration: Configuration) {
    self.initialURL = initialURL
    self.initialTitle = initialTitle
    self.url = initialURL
    self.configuration = configuration
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
    
    webViewObserver = webView.observe(\.url, options: .new) { [weak self] webView, change in
        guard let newURL = change.newValue as? URL else { return }

        if var urlComponents = URLComponents(url: newURL, resolvingAgainstBaseURL: false) {
            var queryItems = urlComponents.queryItems ?? []
            if !queryItems.contains(where: { $0.name == "utm_source" }) {
                queryItems.append(URLQueryItem(name: "utm_source", value: "tonkeeper"))
                urlComponents.queryItems = queryItems

                if let updatedURL = urlComponents.url {
                    self?.webView.load(URLRequest(url: updatedURL))
                }
            }
        }
    }

    
    navigationBar.centerView = titleView
    
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
    view.addSubview(navigationBar)
    
    navigationBar.isHidden = isHeaderHidden
    
    setupConstraints()
    
    didUpdateUrl()
    
    navigationBar.leftViews = [backButton]
    navigationBar.rightViews = [rightPillButton]
    
    backButton.isHidden = true
    canGoBack = webView.observe(\.canGoBack, options: .new) { [weak self] _, value in
      guard let canGoBack = value.newValue else { return }
      self?.backButton.isHidden = !canGoBack
    }
    
    let urlRequest = URLRequest(url: url)
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
  
  private func backButtonAction() {
    webView.goBack()
  }
  
  private func closeButtonAction() {
    webView.scrollView.layer.masksToBounds = true
    webView.layer.masksToBounds = true
    dismiss(animated: true)
  }
  
  private func menuButtonAction() {
    let items = [
      TKPopupMenuItem(
        title: "Refresh",
        icon: .TKUIKit.Icons.Size16.refresh,
        selectionHandler: { [weak self] in
          self?.webView.reload()
        }
      ),
      TKPopupMenuItem(
        title: "Share",
        icon: .TKUIKit.Icons.Size16.share,
        selectionHandler: { [weak self] in
          guard let url = self?.webView.url else { return }
          self?.shareURL(url: url)
        }
      ),
      TKPopupMenuItem(
        title: "Copy link",
        icon: .TKUIKit.Icons.Size16.copy,
        selectionHandler: { [weak self, configuration] in
          guard let url = self?.webView.url else { return }
          ToastPresenter.showToast(configuration: configuration.copyToastConfiguration)
          UIPasteboard.general.string = url.absoluteString
        }
      )
    ]
    TKPopupMenuController.show(
      sourceView: rightPillButton,
      position: .bottomRight(inset: 8),
      width: 0,
      items: items,
      isSelectable: false,
      selectedIndex: nil)
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
  
  private func didUpdateUrl() {
    
    func update(title: String?, caption: String, isSecure: Bool) {
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
        title: caption.withTextStyle(
          .body2,
          color: .Text.secondary,
          alignment: .center,
          lineBreakMode: .byTruncatingTail
        ),
        icon: icon,
        action: nil
      )
      
      let titleConfiguration = TKUINavigationBarTitleView.Model(
        title: title,
        caption: caption
      )
      
      titleView.configure(model: titleConfiguration)
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
