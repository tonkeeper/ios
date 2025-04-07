import UIKit
import TKUIKit
import TKScreenKit
import SnapKit
import TKCore
import KeeperCore

final class DappViewController: UIViewController {
  private let viewModel: DappViewModel
  
  private var bridgeWebViewController: TKBridgeWebViewController?
  private let deeplinkHandler: (_ deeplink: Deeplink) -> Void

  init(viewModel: DappViewModel, deeplinkHandler: @escaping (_ deeplink: Deeplink) -> Void) {
    self.viewModel = viewModel
    self.deeplinkHandler = deeplinkHandler
    super.init(nibName: nil, bundle: nil)
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  override func viewDidLoad() {
    super.viewDidLoad()
    
    setupBinding()
    viewModel.viewDidLoad()
  }
  
  override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
    if viewModel.isLandscapeEnable {
      return .allButUpsideDown
    } else {
      return .portrait
    }
  }
  
  override var shouldAutorotate: Bool {
    viewModel.isLandscapeEnable
  }
}

private extension DappViewController {
  func setupBinding() {
    viewModel.didOpenApp = { [weak self] url, title in
      guard let self, let url else { return }
      
      let bridgeWebViewController = TKBridgeWebViewController(
        initialURL: url,
        initialTitle: title,
        jsInjection: self.viewModel.jsInjection,
        configuration: .default,
        userAgentProvider: TonkeeperBridgeWebViewControllerUserAgentProvider(),
        deeplinkHandler: { url in
          let deeplinkParser = DeeplinkParser()
          let deeplink = try deeplinkParser.parse(string: url)
          self.deeplinkHandler(deeplink)
        })
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
    
    viewModel.didUpdateIsLandscapeEnable = { [weak self] in
      if #available(iOS 16.0, *) {
        self?.setNeedsUpdateOfSupportedInterfaceOrientations()
      } else {
        UIViewController.attemptRotationToDeviceOrientation()
      }
    }
  }
}
