import UIKit
import TKCoordinator
import TKCore
import TKUIKit
import KeeperCore
import TonSwift
import TKLocalize
import URKit
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
  private let transferData: TransferData
  private let keeperCoreMainAssembly: KeeperCore.MainAssembly
  private let coreAssembly: TKCore.CoreAssembly
  
  init(router: ViewControllerRouter,
       wallet: Wallet,
       transferData: TransferData,
       keeperCoreMainAssembly: KeeperCore.MainAssembly,
       coreAssembly: TKCore.CoreAssembly) {
    self.wallet = wallet
    self.transferData = transferData
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
      Task { [weak self] in
        guard let self else { return }
        do {
          let walletTransfer = try await UnsignedTransferBuilder(transferData: transferData)
            .createUnsignedWalletTransfer(
              wallet: wallet
            )
          guard let signedData = await handleSignerSignOnDevice(
            walletTransfer: walletTransfer,
            publicKey: publicKey,
            revision: walletContractVersion,
            network: wallet.identity.network) else {
            throw ExtenalSignError.cancelled
          }
          let signedBoc = try TransferSigner.signWalletTransfer(
            walletTransfer,
            wallet: wallet,
            seqno: transferData.seqno,
            signed: signedData
          ).toBoc().base64EncodedString()
          self.didSign?(signedBoc)
        } catch {
          self.didCancel?()
        }
      }
    case .Signer(let publicKey, let walletContractVersion):
      Task {[weak self] in
        guard let self else { return }
        do {
          let walletTransfer = try await UnsignedTransferBuilder(transferData: transferData)
            .createUnsignedWalletTransfer(
              wallet: wallet
            )
          guard let signedData = await handleSignerSign(
            walletTransfer: walletTransfer,
            publicKey: publicKey,
            revision: walletContractVersion,
            network: wallet.identity.network) else {
            throw ExtenalSignError.cancelled
          }
          let signedBoc = try TransferSigner.signWalletTransfer(
            walletTransfer,
            wallet: wallet,
            seqno: transferData.seqno,
            signed: signedData
          ).toBoc().base64EncodedString()
          self.didSign?(signedBoc)
        } catch {
          self.didCancel?()
        }
      }
    case .Keystone(let publicKey, let xfp, let path, let walletContractVersion):
      Task {[weak self] in
        guard let self else { return }
        do {
          let walletTransfer = try await UnsignedTransferBuilder(transferData: transferData)
            .createUnsignedWalletTransfer(
              wallet: wallet
            )
          guard let ur = await handleKeystoneSign(
            walletTransfer: walletTransfer,
            publicKey: publicKey,
            path: path,
            xfp: xfp,
            revision: walletContractVersion,
            network: wallet.identity.network) else {
            throw ExtenalSignError.cancelled
          }
          
          guard let signature = try TonSignature(cbor: ur.cbor).signature else {
            throw ExtenalSignError.cancelled
          }
          let signedBoc = try TransferSigner.signWalletTransfer(
            walletTransfer,
            wallet: wallet,
            seqno: transferData.seqno,
            signed: signature
          ).toBoc().base64EncodedString()
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
      mnemonicsRepository: keeperCoreMainAssembly.secureAssembly.mnemonicsRepository(),
      securityStore: keeperCoreMainAssembly.storesAssembly.securityStore,
      onCancel: { [weak self] in
        self?.didCancel?()
      },
      onInput: { [weak self, wallet, keeperCoreMainAssembly, transferData] passcode in
        guard let self else { return }
        Task {
          do {
            let mnemonic = try await keeperCoreMainAssembly.secureAssembly.mnemonicsRepository().getMnemonic(
              wallet: wallet,
              password: passcode
            )
            let keyPair = try TonSwift.Mnemonic.mnemonicToPrivateKey(mnemonicArray: mnemonic.mnemonicWords)
            let privateKey = keyPair.privateKey
            let walletTransfer = try await UnsignedTransferBuilder(transferData: transferData)
              .createUnsignedWalletTransfer(
                wallet: wallet
              )
            let signed = try TransferSigner.signWalletTransfer(
              walletTransfer,
              wallet: wallet,
              seqno: transferData.seqno,
              signer: WalletTransferSecretKeySigner(secretKey: privateKey.data)
            )
            self.didSign?(try signed.toBoc().base64EncodedString())
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
  
  func handleKeystoneSign(walletTransfer: WalletTransfer,
                          publicKey: TonSwift.PublicKey,
                          path: String?,
                          xfp: String?,
                          revision: WalletContractVersion,
                          network: Network) async -> UR? {
    await withCheckedContinuation { continuation in
      DispatchQueue.main.async { [wallet] in
        guard let ur = try? self.createKeystoneSignUR(transfer: walletTransfer.signingMessage.endCell().toBoc(),
                                                      path: path,
                                                      xfp: xfp,
                                                      publicKey: publicKey,
                                                      revision: revision,
                                                      network: network,
                                                      isOnDevice: false) else { return }
        let module = KeystoneSignAssembly.module(
          transaction: ur,
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
        
        module.output.didScanSignedTransaction = { [weak bottomSheetViewController] ur in
          bottomSheetViewController?.dismiss {
            continuation.resume(returning: ur)
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
  
  func createKeystoneSignUR(transfer: Data,
                            path: String?,
                            xfp: String?,
                            publicKey: TonSwift.PublicKey,
                            revision: WalletContractVersion,
                            network: Network,
                            isOnDevice: Bool) throws -> UR? {
        
    var cryptoKeypath: CryptoKeyPath? = nil
    if let xfp = xfp {
      if let path = path {
        cryptoKeypath = CryptoKeyPath(components: try CryptoPath.init(string: path), sourceFingerprint: UInt64(xfp), depth: nil)
      }
    }
    
    let tonSignRequest = try TonSignRequest(requestId: nil, signData: transfer, dataType: 1, cryptoKeypath: cryptoKeypath, address: wallet.address.toFriendly(bounceable: false).toString(), origin: "Tonkeeper")
          
    return try UR.init(type: "ton-sign-request", cbor: try tonSignRequest.toCBOR())
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
