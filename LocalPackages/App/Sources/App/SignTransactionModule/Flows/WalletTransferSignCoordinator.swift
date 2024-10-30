import UIKit
import TKCoordinator
import TKCore
import TKUIKit
import KeeperCore
import TonSwift
import TKLocalize
import TonTransport

enum WalletTransferSignError: Swift.Error {
  case incorrectWalletKind
  case cancelled
  case failedToSign(Swift.Error?)
}

final class WalletTransferSignCoordinator: RouterCoordinator<ViewControllerRouter> {
  
  enum ExtenalSignError: Swift.Error {
    case cancelled
  }
  
  enum Result {
    case signed(String)
    case failed(WalletTransferSignError)
    case cancel
  }
  
  var didFail: ((WalletTransferSignError) -> Void)?
  var didSign: ((String) -> Void)?
  var didCancel: (() -> Void)?
  
  var externalSignHandler: ((Data?) -> Void)?
  
  private let wallet: Wallet
  private let transferMessageBuilder: TransferMessageBuilder
  private let keeperCoreMainAssembly: KeeperCore.MainAssembly
  private let coreAssembly: TKCore.CoreAssembly
  
  init(router: ViewControllerRouter,
       wallet: Wallet,
       transferMessageBuilder: TransferMessageBuilder,
       keeperCoreMainAssembly: KeeperCore.MainAssembly,
       coreAssembly: TKCore.CoreAssembly) {
    self.wallet = wallet
    self.transferMessageBuilder = transferMessageBuilder
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
    case .SignerDevice(let publicKey, let walletContractVersion):
      Task {
        do {
          let signedBoc = try await transferMessageBuilder.externalSign(wallet: wallet, signClosure: { transfer in
            guard let data = await handleSignerSignOnDevice(
              walletTransfer: transfer,
              publicKey: publicKey,
              revision: walletContractVersion,
              network: wallet.identity.network) else {
              throw ExtenalSignError.cancelled
            }
            return data
          })
          self.didSign?(signedBoc)
        } catch {
          self.didCancel?()
        }
      }
    case .Signer(let publicKey, let walletContractVersion):
      Task {
        do {
          let signedBoc = try await transferMessageBuilder.externalSign(wallet: wallet, signClosure: { transfer in
            guard let data = await handleSignerSign(
              walletTransfer: transfer,
              publicKey: publicKey,
              revision: walletContractVersion,
              network: wallet.identity.network) else {
              throw ExtenalSignError.cancelled
            }
            return data
          })
          self.didSign?(signedBoc)
        } catch {
          self.didCancel?()
        }
      }
    case .Ledger(_, _, let ledgerDevice):
      Task {
        do {
          let signedBoc = try await transferMessageBuilder.externalSign(wallet: wallet, signClosure: { transfer in
            let transaction = try Transaction.from(transfer: transfer)
            guard let data = await handleLedgerSign(
              transaction: transaction[0],
              ledgerDevice: ledgerDevice
            ) else {
              throw ExtenalSignError.cancelled
            }
            return data
          })
          self.didSign?(signedBoc)
        } catch {
          self.didCancel?()
        }
      }
    case .Lockup, .Watchonly:
      didFail?(.incorrectWalletKind)
    }
  }
  
  func handleRegularSign() {
    PasscodeInputCoordinator.present(
      parentCoordinator: self,
      parentRouter: router,
      mnemonicsRepository: keeperCoreMainAssembly.repositoriesAssembly.mnemonicsRepository(),
      securityStore: keeperCoreMainAssembly.storesAssembly.securityStore,
      onCancel: { [weak self] in
        self?.didCancel?()
      },
      onInput: { [weak self, wallet, keeperCoreMainAssembly, transferMessageBuilder] passcode in
        guard let self else { return }
        Task {
          do {
            let mnemonic = try await keeperCoreMainAssembly.repositoriesAssembly.mnemonicsRepository().getMnemonic(
              wallet: wallet,
              password: passcode
            )
            let keyPair = try TonSwift.Mnemonic.mnemonicToPrivateKey(mnemonicArray: mnemonic.mnemonicWords)
            let privateKey = keyPair.privateKey
            let signedBoc = try await transferMessageBuilder.externalSign(wallet: wallet) { walletTransfer in
              return try walletTransfer.signMessage(signer: WalletTransferSecretKeySigner(secretKey: privateKey.data))
            }
            self.didSign?(signedBoc)
          } catch {
            self.didFail?(.failedToSign(error))
          }
        }
      }
    )
  }
  
  func handleLedgerSign(transaction: Transaction, ledgerDevice: Wallet.LedgerDevice) async -> Data? {
    await withCheckedContinuation { continuation in
      DispatchQueue.main.async {
        let module = LedgerConfirmAssembly.module(transaction: transaction,
                                                  wallet: self.wallet,
                                                  ledgerDevice: ledgerDevice,
                                                  coreAssembly: self.coreAssembly)
        
        let bottomSheetViewController = TKBottomSheetViewController(contentViewController: module.view)
        
        bottomSheetViewController.didClose = { isInteractivly in
          guard !isInteractivly else {
            continuation.resume(returning: nil)
            return
          }
        }
        
        module.output.didCancel = { [weak bottomSheetViewController] in
          bottomSheetViewController?.dismiss(completion: {
            continuation.resume(returning: nil)
          })
        }
        
        module.output.didSign = { [weak bottomSheetViewController] signature in
          bottomSheetViewController?.dismiss(completion: {
            continuation.resume(returning: signature)
          })
        }
        
        module.output.didError = { [weak bottomSheetViewController, weak self] error in
          bottomSheetViewController?.dismiss(completion: {
            self?.handleLedgerConfirmError(error)
            continuation.resume(returning: nil)
          })
        }
        
        bottomSheetViewController.present(fromViewController: self.router.rootViewController)
      }
    }
  }
  
  func handleSignerSign(walletTransfer: WalletTransfer,
                        publicKey: TonSwift.PublicKey,
                        revision: WalletContractVersion,
                        network: Network) async -> Data? {
    await withCheckedContinuation { continuation in
      DispatchQueue.main.async { [wallet] in
        guard let url = try? self.createTonSignURL(transfer: walletTransfer.signingMessage.endCell().toBoc(),
                                                   publicKey: publicKey,
                                                   revision: revision,
                                                   network: network,
                                                   isOnDevice: false) else { return }
        let module = SignerSignAssembly.module(
          url: url,
          wallet: wallet,
          assembly: self.keeperCoreMainAssembly,
          coreAssembly: self.coreAssembly
        )
        let bottomSheetViewController = TKBottomSheetViewController(contentViewController: module.view)
        
        bottomSheetViewController.didClose = { [weak bottomSheetViewController] isInteractivly in
          guard isInteractivly else { return }
          bottomSheetViewController?.dismiss(completion: {
            continuation.resume(returning: nil)
          })
        }
        
        module.output.didScanSignedTransaction = { [weak bottomSheetViewController] sign in
          bottomSheetViewController?.dismiss {
            continuation.resume(returning: sign)
          }
        }
        
        bottomSheetViewController.present(fromViewController: self.router.rootViewController)
      }
    }
  }
  
  func handleSignerSignOnDevice(walletTransfer: WalletTransfer,
                                publicKey: TonSwift.PublicKey,
                                revision: WalletContractVersion,
                                network: Network) async -> Data? {
    await withCheckedContinuation { continuation in
      guard let url = try? createTonSignURL(transfer: walletTransfer.signingMessage.endCell().toBoc(),
                                            publicKey: publicKey,
                                            revision: revision,
                                            network: network,
                                            isOnDevice: true) else {
        continuation.resume(returning: nil)
        return
      }
      externalSignHandler = { data in
        continuation.resume(returning: data)
      }
      DispatchQueue.main.async {
        self.coreAssembly.urlOpener().open(url: url)
      }
    }
  }
  
  func createTonSignURL(transfer: Data,
                        publicKey: TonSwift.PublicKey,
                        revision: WalletContractVersion,
                        network: Network,
                        isOnDevice: Bool) -> URL? {
    let hexPublicKey = publicKey.data.hexString()
    let hexBody = transfer.hexString()
    let v = revision.rawValue.lowercased()
    
    var string = "tonsign://v1/?pk=\(hexPublicKey)&body=\(hexBody)&v=\(v)&tn=\(network.rawValue)"
    if isOnDevice {
      string.append("&return=\("tonkeeperx://publish".percentEncoded ?? "")")
    }
    return URL(string: string)
  }
  
  func handleLedgerConfirmError(_ error: LedgerConfirmError) {
    switch error {
    case .versionTooLow(_, let requiredVersion):
      let module = UpdatePopupAssembly.module()
      
      let configuration = UpdatePopupConfiguration(
        icon: .TKUIKit.Icons.Size96.tonIcon,
        title: TKLocales.LedgerVersionUpdate.title(requiredVersion),
        caption: TKLocales.LedgerVersionUpdate.caption,
        buttons: [UpdatePopupConfiguration.Button(
          title: TKLocales.Actions.ok,
          category: .secondary,
          action: {
            module.view.dismiss()
          }
        )]
      )
      
      module.input.setConfiguration(configuration)
      
      module.view.present(fromViewController: self.router.rootViewController)
    }
  }
}
