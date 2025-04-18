import UIKit
import TKUIKit
import TKCore
import TKCoordinator
import KeeperCore

@MainActor
public final class SignDataCoordinator: RouterCoordinator<WindowRouter> {
  private let wallet: Wallet
  private let dappUrl: String
  private let signRequest: TonConnect.SignDataRequest
  private let didRequireSign: ((TonConnect.SignDataRequest, String, Wallet, UIViewController) async throws -> SignedDataResult?)?
  private let resultHandler: SignDataResultHandler
  private let keeperCoreMainAssembly: KeeperCore.MainAssembly

  public init(
    router: WindowRouter,
    wallet: Wallet,
    dappUrl: String,
    signRequest: TonConnect.SignDataRequest,
    resultHandler: SignDataResultHandler,
    didRequireSign: ((TonConnect.SignDataRequest, String, Wallet, UIViewController) async throws -> SignedDataResult?)?,
    keeperCoreMainAssembly: KeeperCore.MainAssembly
  ) {
    self.wallet = wallet
    self.dappUrl = dappUrl
    self.signRequest = signRequest
    self.didRequireSign = didRequireSign
    self.resultHandler = resultHandler
    self.keeperCoreMainAssembly = keeperCoreMainAssembly
    super.init(router: router)
  }

  public override func start() {
    let module = SignDataAssembly.module(
      wallet: wallet,
      dappUrl: dappUrl,
      signRequest: signRequest,
      resultHandler: resultHandler,
      keeperCoreMainAssembly: keeperCoreMainAssembly
    )
        
    weak var moduleInput = module.input

    let containerViewController = TKBottomSheetViewController(contentViewController: module.view)
    containerViewController.didClose = { [weak self] isInteractivly in
      guard let self else { return }
      guard isInteractivly else { return }
      moduleInput?.cancel()
      self.didFinish?(self)
    }
    
    module.output.didRequireSign = { [weak self] signDataRequest, dappUrl, wallet in
      try await self?.didRequireSign?(signDataRequest, dappUrl, wallet, containerViewController)
    }
    
    module.output.didConfirm = { [weak self] in
      guard let self else { return }
      self.didFinish?(self)
    }
    
    let rootViewController = UIViewController()
    router.window.rootViewController = rootViewController
    router.window.makeKeyAndVisible()
    
    
    containerViewController.present(fromViewController: rootViewController)
  }
}
