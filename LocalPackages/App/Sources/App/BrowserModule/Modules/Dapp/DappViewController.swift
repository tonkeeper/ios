import UIKit
import TKUIKit
import TKScreenKit
import SnapKit
  import TKCore

final class DappViewController: UIViewController {
  private let viewModel: DappViewModel
  private let analyticsProvider: AnalyticsProvider
  
  private var bridgeWebViewController: TKBridgeWebViewController?

  init(viewModel: DappViewModel, analyticsProvider: AnalyticsProvider) {
    self.viewModel = viewModel
    self.analyticsProvider = analyticsProvider
    super.init(nibName: nil, bundle: nil)
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  override func viewDidLoad() {
    super.viewDidLoad()
    
    setup()
    setupBinding()
    viewModel.viewDidLoad()
  }
}

private extension DappViewController {
  func setup() {
    
  }
  
  func setupBinding() {
    viewModel.didOpenApp = { [weak self] url, title in
      guard let self, let url else { return }
      
      self.analyticsProvider.logEvent(eventKey: .clickDapp, args: ["name": title ?? "", "url": url.absoluteString])
      
      let bridgeWebViewController = TKBridgeWebViewController(
        initialURL: url,
        initialTitle: title,
        jsInjection: self.viewModel.jsInjection
      )
      bridgeWebViewController.didLoadInitialURLHandler = { [weak self] in
        self?.viewModel.didLoadInitialRequest()
      }
      self.addChild(bridgeWebViewController)
      self.view.addSubview(bridgeWebViewController.view)
      bridgeWebViewController.didMove(toParent: self)
      
      bridgeWebViewController.view.snp.makeConstraints { make in
        make.edges.equalTo(self.view)
      }
      bridgeWebViewController.addBridgeMessageObserver(message: "dapp", observer: { [weak self] body in
        self?.viewModel.didReceiveMessage(body: body)
      })
      
      self.bridgeWebViewController = bridgeWebViewController
    }
    
    viewModel.injectHandler = { [weak self] jsInjection in
      Task {
        do {
          try await self?.bridgeWebViewController?.evaulateJavaScript(jsInjection)
        } catch {
          print(error)
        }
      }
    }
  }
}
