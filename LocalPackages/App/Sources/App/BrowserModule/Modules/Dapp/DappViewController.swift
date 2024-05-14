import UIKit
import TKUIKit
import TKScreenKit
import SnapKit

final class DappViewController: UIViewController {
  private let viewModel: DappViewModel
  
  private var bridgeWebViewController: TKBridgeWebViewController?

  init(viewModel: DappViewModel) {
    self.viewModel = viewModel
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
      
      let bridgeWebViewController = TKBridgeWebViewController(
        initialURL: url,
        initialTitle: title
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
    
    viewModel.injectHandler = { [weak self] jsInjection, completion in
      Task {
        do {
          try await self?.bridgeWebViewController?.evaulateJavaScript(jsInjection)
          completion?()
        } catch {
          print(error)
        }
      }
    }
  }
}
