import UIKit
import TKCoordinator
import TKUIKit
import KeeperCore
import TonSwift

enum WalletTransferSignError: Swift.Error {
  case incorrectWalletKind
  case failedToSign(Swift.Error)
}

final class WalletTransferSignCoordinator: RouterCoordinator<ViewControllerRouter> {
  
  enum Result {
    case signed(Data)
    case failed(WalletTransferSignError)
    case cancel
  }
  
  var didFail: ((WalletTransferSignError) -> Void)?
  var didSign: ((Data) -> Void)?
  var didCancel: (() -> Void)?
  
  private let wallet: Wallet
  private let walletTransfer: WalletTransfer
  private let keeperCoreMainAssembly: KeeperCore.MainAssembly
  
  init(router: ViewControllerRouter,
       wallet: Wallet,
       walletTransfer: WalletTransfer,
       keeperCoreMainAssembly: KeeperCore.MainAssembly) {
    self.wallet = wallet
    self.walletTransfer = walletTransfer
    self.keeperCoreMainAssembly = keeperCoreMainAssembly
    super.init(router: router)
  }
  
  override func start() {
    handleSign()
  }
  
  func handleSign(parentCoordinator: Coordinator) async -> Result {
    return await Task<WalletTransferSignCoordinator.Result, Never> { @MainActor in
      return await withCheckedContinuation { (continuation: CheckedContinuation<WalletTransferSignCoordinator.Result, Never>) in
        didSign = { [weak parentCoordinator, weak self] in
          continuation.resume(returning: .signed($0))
          guard let self else { return }
          parentCoordinator?.removeChild(self)
        }
        
        didFail = { [weak parentCoordinator, weak self] in
          continuation.resume(returning: .failed($0))
          guard let self else { return }
          parentCoordinator?.removeChild(self)
        }
        
        didCancel = { [weak parentCoordinator, weak self] in
          continuation.resume(returning: .cancel)
          guard let self else { return }
          parentCoordinator?.removeChild(self)
        }
        
        parentCoordinator.addChild(self)
        start()
      }
    }.value
  }
}

private extension WalletTransferSignCoordinator {
  func handleSign() {
    switch wallet.identity.kind {
    case .Regular:
      handleRegularSign()
    case .External:
      handleExternalSign()
    case .Lockup, .Watchonly:
      didFail?(.incorrectWalletKind)
    }
  }
  
  func handleRegularSign() {
    let coordinator = PasscodeModule(
      dependencies: PasscodeModule.Dependencies(
        passcodeAssembly: keeperCoreMainAssembly.passcodeAssembly
      )
    ).passcodeConfirmationCoordinator()
    
    coordinator.didCancel = { [weak self, weak coordinator] in
      coordinator?.router.dismiss(completion: {
        self?.didCancel?()
        guard let coordinator else { return }
        self?.removeChild(coordinator)
      })
    }
    
    coordinator.didConfirm = { [weak self, weak coordinator, keeperCoreMainAssembly, wallet, walletTransfer] in
      do {
        let mnemonic = try keeperCoreMainAssembly.repositoriesAssembly.mnemonicRepository().getMnemonic(forWallet: wallet)
        let keyPair = try TonSwift.Mnemonic.mnemonicToPrivateKey(mnemonicArray: mnemonic.mnemonicWords)
        let privateKey = keyPair.privateKey
        let signed = try walletTransfer.signMessage(signer: WalletTransferSecretKeySigner(secretKey: privateKey.data))
        self?.didSign?(signed)
      } catch {
        self?.didFail?(.failedToSign(error))
      }
      coordinator?.router.dismiss(completion: {
        guard let coordinator else { return }
        self?.removeChild(coordinator)
      })
    }
    
    addChild(coordinator)
    coordinator.start()
    
    router.rootViewController.present(coordinator.router.rootViewController, animated: true)
  }
  
  func handleExternalSign() {
    
  }
}
