import UIKit
import TKCoordinator
import TKCore
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
  
  var externalSignHandler: ((Data?) -> Void)?
  
  private let wallet: Wallet
  private let walletTransfer: WalletTransfer
  private let keeperCoreMainAssembly: KeeperCore.MainAssembly
  private let coreAssembly: TKCore.CoreAssembly
  
  init(router: ViewControllerRouter,
       wallet: Wallet,
       walletTransfer: WalletTransfer,
       keeperCoreMainAssembly: KeeperCore.MainAssembly,
       coreAssembly: TKCore.CoreAssembly) {
    self.wallet = wallet
    self.walletTransfer = walletTransfer
    self.keeperCoreMainAssembly = keeperCoreMainAssembly
    self.coreAssembly = coreAssembly
    super.init(router: router)
  }
  
  override func start() {
    handleSign()
  }
  
  func handleSign(parentCoordinator: Coordinator) async -> Result {
    return await Task<WalletTransferSignCoordinator.Result, Never> { @MainActor in
      return await withCheckedContinuation { [weak parentCoordinator] (continuation: CheckedContinuation<WalletTransferSignCoordinator.Result, Never>) in
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
        
        parentCoordinator?.addChild(self)
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
    case .External(let publicKey, let walletContractVersion):
      handleExternalSign(
        transfer: walletTransfer,
        publicKey: publicKey,
        revision: walletContractVersion
      )
    case .Lockup, .Watchonly:
      didFail?(.incorrectWalletKind)
    }
  }
  
  func handleRegularSign() {
    PasscodeInputCoordinator.present(
      parentCoordinator: self,
      parentRouter: router,
      repositoriesAssembly: keeperCoreMainAssembly.repositoriesAssembly,
      onCancel: { [weak self] in
        self?.didCancel?()
      },
      onInput: { [weak self, wallet, keeperCoreMainAssembly, walletTransfer] passcode in
        guard let self else { return }
        Task {
          do {
            let mnemonic = try await keeperCoreMainAssembly.repositoriesAssembly.mnemonicsRepository().getMnemonic(
              wallet: wallet,
              password: passcode
            )
            let keyPair = try TonSwift.Mnemonic.mnemonicToPrivateKey(mnemonicArray: mnemonic.mnemonicWords)
            let privateKey = keyPair.privateKey
            let signed = try walletTransfer.signMessage(signer: WalletTransferSecretKeySigner(secretKey: privateKey.data))
            self.didSign?(signed)
          } catch {
            self.didFail?(.failedToSign(error))
          }
        }
      }
    )
  }
  
  func handleExternalSign(transfer: WalletTransfer,
                          publicKey: TonSwift.PublicKey,
                          revision: WalletContractVersion) {
    guard let url = try? createTonSignURL(transfer: transfer.signingMessage.endCell().toBoc(),
                                          publicKey: publicKey,
                                          revision: revision) else { return }
    
    if coreAssembly.urlOpener().canOpen(url: url) {
      externalSignHandler = { [weak self] data in
        guard let data else {
          self?.didCancel?()
          return
        }
        self?.didSign?(data)
      }
      coreAssembly.urlOpener().open(url: url)
    } else {
      let module = SignerSignAssembly.module(
        url: url,
        wallet: wallet,
        assembly: self.keeperCoreMainAssembly,
        coreAssembly: self.coreAssembly
      )
      let bottomSheetViewController = TKBottomSheetViewController(contentViewController: module.view)
      
      bottomSheetViewController.didClose = { [weak self, weak bottomSheetViewController] isInteractivly in
        guard isInteractivly else { return }
        bottomSheetViewController?.dismiss(completion: {
          self?.didCancel?()
          return
        })
      }
      
      module.output.didScanSignedTransaction = { [weak self, weak bottomSheetViewController] model in
        bottomSheetViewController?.dismiss {
          self?.didSign?(model.sign)
        }
      }
      
      bottomSheetViewController.present(fromViewController: router.rootViewController)
    }
  }
  
  func createTonSignURL(transfer: Data, publicKey: TonSwift.PublicKey, revision: WalletContractVersion) -> URL? {
    let hexPublicKey = publicKey.data.hexString()
    let hexBody = transfer.hexString()
    let v = revision.rawValue.lowercased()
    
    let string = "tonsign://?pk=\(hexPublicKey)&body=\(hexBody)&v=\(v)&return=\("tonkeeperx://publish".percentEncoded ?? "")"
    return URL(string: string)
  }
}
