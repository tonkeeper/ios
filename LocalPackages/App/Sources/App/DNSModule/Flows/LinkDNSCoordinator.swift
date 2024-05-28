import UIKit
import KeeperCore
import TKCoordinator
import TKUIKit
import TKCore
import TonSwift

final class LinkDNSCoordinator: RouterCoordinator<WindowRouter> {
  
  enum Flow {
    case link
    case unlink
  }
  
  var didCancel: (() -> Void)?
  var didFinish: (() -> Void)?
  
  private let externalSignHandler = ExternalSignHandler()
  
  private let wallet: Wallet
  private let flow: Flow
  private let linkDNSController: LinkDNSController
  private let keeperCoreMainAssembly: KeeperCore.MainAssembly
  private let coreAssembly: TKCore.CoreAssembly
  
  init(router: WindowRouter,
       wallet: Wallet,
       flow: Flow,
       linkDNSController: LinkDNSController,
       keeperCoreMainAssembly: KeeperCore.MainAssembly,
       coreAssembly: TKCore.CoreAssembly) {
    self.wallet = wallet
    self.flow = flow
    self.linkDNSController = linkDNSController
    self.keeperCoreMainAssembly = keeperCoreMainAssembly
    self.coreAssembly = coreAssembly
    super.init(router: router)
  }
  
  override func start() {
    ToastPresenter.showToast(configuration: .loading)
    Task {
      do {
        let dnsLink: DNSLink
        switch flow {
        case .link:
          dnsLink = try .link(address: .friendly(wallet.friendlyAddress))
        case .unlink:
          dnsLink = .unlink
        }
        let model = try await linkDNSController.emulate(dnsLink: dnsLink)
        await MainActor.run {
          ToastPresenter.hideAll()
          openConfirmation(model: model, dnsLink: dnsLink)
        }
      } catch {
        await MainActor.run {
          ToastPresenter.hideAll()
          didCancel?()
        }
      }
    }
  }
}

private extension LinkDNSCoordinator {
  func openConfirmation(model: SendTransactionModel, dnsLink: DNSLink) {
    let rootViewController = UIViewController()
    router.window.rootViewController = rootViewController
    router.window.makeKeyAndVisible()

    let module = LinkDNSAssembly.module(
      model: model,
      dnsLink: dnsLink,
      keeperCoreMainAssembly: keeperCoreMainAssembly
    )
    let bottomSheetViewController = TKBottomSheetViewController(contentViewController: module.view)
    
    bottomSheetViewController.didClose = { [weak self] isInteractivly in
      self?.didCancel?()
    }
    
    module.output.didCancel = { [weak self, weak bottomSheetViewController] in
      bottomSheetViewController?.dismiss(completion: {
        self?.didCancel?()
      })
    }
    
    module.output.didTapConfirmButton = { [weak self, weak bottomSheetViewController] dnsLink in
      guard let self, let bottomSheetViewController else { return false }
      return await self.performLink(
        fromViewController: bottomSheetViewController,
        dnsLink: dnsLink
      )
    }
    
    module.output.didLink = { [weak self, weak bottomSheetViewController] in
      bottomSheetViewController?.dismiss(completion: {
        self?.didFinish?()
      })
    }
    
    bottomSheetViewController.present(fromViewController: rootViewController)
  }
  
  func performLink(fromViewController: UIViewController, dnsLink: DNSLink) async -> Bool {
    let isConfirmed = await PasscodePresenter.presentPasscodeConfirmation(
      fromViewController: fromViewController,
      parentCoordinator: self,
      keeperCoreMainAssembly: keeperCoreMainAssembly
    )
    guard isConfirmed else { return false }
    
    do {
      try await linkDNSController.sendLinkTransaction(
        dnsLink: dnsLink) { [externalSignHandler, keeperCoreMainAssembly, coreAssembly] url, wallet in
          try await externalSignHandler.performExternalSign(
            url: url,
            wallet: wallet,
            fromViewController: fromViewController,
            keeperCoreMainAssembly: keeperCoreMainAssembly,
            coreAssembly: coreAssembly
          )
        }
      return true
    } catch {
      return false
    }
  }
}
