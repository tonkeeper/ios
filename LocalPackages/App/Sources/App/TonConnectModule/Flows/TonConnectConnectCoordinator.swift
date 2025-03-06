import UIKit
import KeeperCore
import TKCoordinator
import TKUIKit
import TKScreenKit
import TKCore
import TonSwift
import URKit

enum ConnectError: Error {
  case unknown
  case noPasscode
}

@MainActor
public protocol TonConnectConnectCoordinatorConnector {
  func connect(wallet: Wallet,
               parameters: TonConnectParameters,
               manifest: TonConnectManifest,
               signTonProofHandler: @escaping (_ payload: String) async throws -> TonConnect.ConnectItemReply) async throws
}

@MainActor
public struct DefaultTonConnectConnectCoordinatorConnector: TonConnectConnectCoordinatorConnector {
  private let tonConnectAppsStore: TonConnectAppsStore
  
  public func connect(wallet: Wallet, 
                      parameters: TonConnectParameters,
                      manifest: TonConnectManifest,
                      signTonProofHandler: @escaping (_ payload: String) async throws -> TonConnect.ConnectItemReply) async throws {
    try await tonConnectAppsStore.connect(
      wallet: wallet,
      parameters: parameters,
      manifest: manifest,
      signTonProofHandler: signTonProofHandler,
      keeperVersion: InfoProvider.appVersion()
    )
  }
  
  public init(tonConnectAppsStore: TonConnectAppsStore) {
    self.tonConnectAppsStore = tonConnectAppsStore
  }
}

@MainActor
public struct BridgeTonConnectConnectCoordinatorConnector: TonConnectConnectCoordinatorConnector {
  private let tonConnectAppsStore: TonConnectAppsStore
  private let connectionResponseHandler: (TonConnectAppsStore.ConnectResult) -> Void
  
  public init(tonConnectAppsStore: TonConnectAppsStore, connectionResponseHandler: @escaping (TonConnectAppsStore.ConnectResult) -> Void) {
    self.tonConnectAppsStore = tonConnectAppsStore
    self.connectionResponseHandler = connectionResponseHandler
  }
  
  public func connect(wallet: Wallet, 
                      parameters: TonConnectParameters,
                      manifest: TonConnectManifest,
                      signTonProofHandler: @escaping (_ payload: String) async throws -> TonConnect.ConnectItemReply) async throws {
    let response = await tonConnectAppsStore.connectBridgeDapp(
      wallet: wallet,
      parameters: parameters,
      manifest: manifest,
      signTonProofHandler: signTonProofHandler,
      keeperVersion: InfoProvider.appVersion()
    )
    connectionResponseHandler(response)
    guard case let .error(error) = response else {
      return
    }
    throw error
  }
}

@MainActor
public final class TonConnectConnectCoordinator: RouterCoordinator<ViewControllerRouter> {

  public enum Flow {
    case common
    case deeplink
  }

  public var didConnect: (() -> Void)?
  public var didCancel: (() -> Void)?
  public var didRequestOpeningBrowser: ((_ manifest: TonConnectManifest) -> Void)?

  private let connector: TonConnectConnectCoordinatorConnector
  private let parameters: TonConnectParameters
  private let manifest: TonConnectManifest
  private let showWalletPicker: Bool
  private let coreAssembly: TKCore.CoreAssembly
  private let keeperCoreMainAssembly: KeeperCore.MainAssembly

  private let flow: Flow

  public init(router: ViewControllerRouter,
              flow: Flow,
              connector: TonConnectConnectCoordinatorConnector,
              parameters: TonConnectParameters,
              manifest: TonConnectManifest,
              showWalletPicker: Bool,
              coreAssembly: TKCore.CoreAssembly,
              keeperCoreMainAssembly: KeeperCore.MainAssembly) {
    self.connector = connector
    self.parameters = parameters
    self.manifest = manifest
    self.showWalletPicker = showWalletPicker
    self.coreAssembly = coreAssembly
    self.keeperCoreMainAssembly = keeperCoreMainAssembly
    self.flow = flow
    super.init(router: router)
  }
  
  public override func start() {
    openTonConnectConnect()
  }
}

private extension TonConnectConnectCoordinator {

  func openTonConnectConnect() {
    let module = TonConnectConnectAssembly.module(
      parameters: parameters,
      manifest: manifest,
      walletsStore: keeperCoreMainAssembly.storesAssembly.walletsStore,
      walletNotificationStore: keeperCoreMainAssembly.storesAssembly.walletNotificationStore,
      notificationsService: keeperCoreMainAssembly.servicesAssembly.notificationsService(
        walletNotificationsStore: keeperCoreMainAssembly.storesAssembly.walletNotificationStore,
        tonConnectAppsStore: keeperCoreMainAssembly.tonConnectAssembly.tonConnectAppsStore
      ),
      pushTokenProvider: PushNotificationTokenProvider(),
      showWalletPicker: showWalletPicker,
      isSafeMode: {
        switch flow {
        case .common:
          return false
        case .deeplink:
          return true
        }
      }()
    )
    
    let bottomSheetViewController = TKBottomSheetViewController(
      contentViewController: module.view
    )
    
    module.output.didTapWalletPicker = { [weak self, weak bottomSheetViewController, weak input = module.input] wallet in
      guard let bottomSheetViewController else { return }
      self?.openWalletPicker(
        wallet: wallet,
        fromViewController: bottomSheetViewController,
        didSelectWallet: { wallet in
          input?.setWallet(wallet)
        }
      )
    }

    module.output.didTapOpenBrowserAndConnect = { [weak bottomSheetViewController] manifest in
      bottomSheetViewController?.dismiss() { [weak self] in
        self?.didRequestOpeningBrowser?(manifest)
        self?.didCancel?()
      }
    }

    module.output.connect = { [weak self, weak bottomSheetViewController] connectParameters in
      guard let self, let bottomSheetViewController else { return false }
      return await self.connect(parameters: connectParameters, fromViewController: bottomSheetViewController)
    }
    
    module.output.didConnect = { [weak self, weak bottomSheetViewController] in
      bottomSheetViewController?.dismiss {
        self?.didConnect?()
      }
      if let returnStrategy = self?.parameters.returnStrategy {
        guard let url = URL(string: returnStrategy) else {
          return
        }
        if UIApplication.shared.canOpenURL(url) {
          UIApplication.shared.open(url, options: [:], completionHandler: nil)
        }
      }
    }
    
    bottomSheetViewController.didClose = { [weak self] isInteractivly in
      guard isInteractivly else { return }
      self?.didCancel?()
    }
    
    bottomSheetViewController.present(fromViewController: router.rootViewController)
  }
  
  func connect(
    parameters: TonConnectConnectParameters,
    fromViewController: UIViewController
  ) async -> Bool {
    let signTonProofHandler: (String) async throws -> TonConnect.ConnectItemReply = { [weak self, unowned fromViewController] payload in
      guard let self = self else { throw ConnectError.unknown }
      
      let wallet = parameters.wallet
      let address = try wallet.address
      let timestamp = UInt64(Date().timeIntervalSince1970)
      
      let signatureData: TonConnect.SignatureData = .init(address: address, domain: .init(domain: parameters.manifest.host), timestamp: timestamp, payload: payload)
      
      switch (wallet.identity.kind) {
      case .Ledger(_, _, let ledgerDevice):
        let signature = try await self.handleLedgerProof(fromViewController: fromViewController,
                                                         signatureData: signatureData,
                                                         wallet: wallet,
                                                         ledgerDevice: ledgerDevice)
        return .tonProofSigned(
          TonConnect.TonProofItemReplySigned.success(
            TonConnect.TonProofItemReplySignedSuccess(
              data: signatureData,
              signature: signature
            )
          )
        )
      case .Keystone(let publicKey, let xfp, let path, let walletContractVersion):
        return await .tonProofSigned(
          .success(.init(data: signatureData,
                         signature: try self.handleKeystoneSign(fromViewController: fromViewController,
                                                                signatureData: signatureData,
                                                                wallet: wallet,
                                                                publicKey: publicKey,
                                                                path: path,
                                                                xfp: xfp,
                                                                revision: walletContractVersion,
                                                                network: wallet.identity.network))))
      default:
        return await .tonProofSigned(.success(
          .init(data: signatureData,
                signature: try self.handleCommonProof(signatureData: signatureData,
                                                      fromViewController: fromViewController,
                                                      wallet: wallet)))
        )
      }
    }
    
    do {
      try await connector.connect(
        wallet: parameters.wallet,
        parameters: parameters.parameters,
        manifest: parameters.manifest,
        signTonProofHandler: signTonProofHandler
      )
      return true
    } catch {
      return false
    }
  }
  
  func handleKeystoneSign(fromViewController: UIViewController,
                          signatureData: TonConnect.SignatureData,
                          wallet: Wallet,
                          publicKey: TonSwift.PublicKey,
                          path: String?,
                          xfp: String?,
                          revision: WalletContractVersion,
                          network: Network) async throws -> Data {
    try await withCheckedThrowingContinuation { continuation in
      DispatchQueue.main.async {
        
        do {
          var cryptoKeypath: CryptoKeyPath? = nil
          if let xfp = xfp {
            if let path = path {
              cryptoKeypath = CryptoKeyPath(components: try CryptoPath.init(string: path), sourceFingerprint: UInt64(xfp), depth: nil)
            }
          }
          
          let tonSignRequest = try TonSignRequest(requestId: nil, signData: signatureData.data(), dataType: 2, cryptoKeypath: cryptoKeypath, address: wallet.address.toFriendly(bounceable: false).toString(), origin: "Tonkeeper")
          
          let ur = try UR.init(type: "ton-sign-request", cbor: try tonSignRequest.toCBOR())
          
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
              continuation.resume(throwing: ConnectError.unknown)
            })
          }
          
          module.output.didScanSignedTransaction = { [weak bottomSheetViewController] ur in
            bottomSheetViewController?.dismiss {
              guard let signature = try? TonSignature(cbor: ur.cbor).signature else { return }
              continuation.resume(returning: signature)
            }
          }
          
          bottomSheetViewController.present(fromViewController: fromViewController)
        } catch {
          continuation.resume(throwing: ConnectError.unknown)
        }
      }
    }
  }
  
  func handleLedgerProof(fromViewController: UIViewController, signatureData: TonConnect.SignatureData, wallet: Wallet, ledgerDevice: Wallet.LedgerDevice) async throws -> Data {
    try await withCheckedThrowingContinuation { continuation in
      DispatchQueue.main.async {
        let module = LedgerConfirmAssembly.module(confirmItem: .signatureData(signatureData),
                                                  wallet: wallet,
                                                  ledgerDevice: ledgerDevice,
                                                  coreAssembly: self.coreAssembly)
        
        let bottomSheetViewController = TKBottomSheetViewController(contentViewController: module.view)
        
        bottomSheetViewController.didClose = { isInteractivly in
          guard !isInteractivly else {
            continuation.resume(throwing: ConnectError.unknown)
            return
          }
        }
        
        module.output.didCancel = { [weak bottomSheetViewController] in
          bottomSheetViewController?.dismiss(completion: {
            continuation.resume(throwing: ConnectError.unknown)
          })
        }
        
        module.output.didSign = { [weak bottomSheetViewController] signature in
          bottomSheetViewController?.dismiss(completion: {
            switch (signature) {
            case.proof(let data):
              continuation.resume(returning: data)
            default:
              continuation.resume(throwing: ConnectError.unknown)
            }
          })
        }
        
        module.output.didError = { [weak bottomSheetViewController] error in
          bottomSheetViewController?.dismiss(completion: {
            continuation.resume(throwing: ConnectError.unknown)
          })
        }
        
        bottomSheetViewController.present(fromViewController: fromViewController)
      }
    }
  }
  
  func handleCommonProof(signatureData: TonConnect.SignatureData,
                         fromViewController: UIViewController,
                         wallet: Wallet) async throws -> Data {
    guard let passcode = await PasscodeInputCoordinator.getPasscode(
      parentCoordinator: self,
      parentRouter: ViewControllerRouter(rootViewController: fromViewController),
      mnemonicsRepository: keeperCoreMainAssembly.secureAssembly.mnemonicsRepository(),
      securityStore: keeperCoreMainAssembly.storesAssembly.securityStore
    ) else { throw ConnectError.noPasscode }
    
    let mnemonic = try await keeperCoreMainAssembly.secureAssembly.mnemonicsRepository().getMnemonic(wallet: wallet, password: passcode)
    let keyPair = try TonSwift.Mnemonic.anyMnemonicToPrivateKey(mnemonicArray: mnemonic.mnemonicWords)
    let privateKey = keyPair.privateKey
    
    let signature: TonConnect.Signature = .init(signatureData: signatureData, privateKey: privateKey)
    return try signature.signature()
  }
  
  func openWalletPicker(wallet: Wallet, fromViewController: UIViewController, didSelectWallet: @escaping (Wallet) -> Void) {
    let model = TonConnectWalletsPickerListModel(
      walletsStore: keeperCoreMainAssembly.storesAssembly.walletsStore,
      selectedWallet: wallet
    )
    model.didSelectWallet = { wallet in
      didSelectWallet(wallet)
    }
    
    let module = WalletsListAssembly.module(
      model: model,
      balanceLoader: keeperCoreMainAssembly.loadersAssembly.balanceLoader,
      totalBalancesStore: keeperCoreMainAssembly.storesAssembly.totalBalanceStore,
      appSettingsStore: keeperCoreMainAssembly.storesAssembly.appSettingsStore,
      decimalAmountFormatter: keeperCoreMainAssembly.formattersAssembly.decimalAmountFormatter,
      amountFormatter: keeperCoreMainAssembly.formattersAssembly.amountFormatter
    )
    
    let bottomSheetViewController = TKBottomSheetViewController(contentViewController: module.view)
    
    module.output.addButtonEvent = { [weak self, unowned bottomSheetViewController] in
      self?.openAddWallet(router: ViewControllerRouter(rootViewController: bottomSheetViewController)) {
      }
    }
    
    module.output.didSelectWallet = { [weak bottomSheetViewController] in
      bottomSheetViewController?.dismiss()
    }
    
    bottomSheetViewController.present(fromViewController: fromViewController)
  }
  
  func openAddWallet(router: ViewControllerRouter, onAddWallets: @escaping () -> Void) {
    let module = AddWalletModule(
      dependencies: AddWalletModule.Dependencies(
        walletsUpdateAssembly: keeperCoreMainAssembly.walletUpdateAssembly,
        storesAssembly: keeperCoreMainAssembly.storesAssembly,
        coreAssembly: coreAssembly,
        scannerAssembly: keeperCoreMainAssembly.scannerAssembly()
      )
    )
    
    let coordinator = module.createAddWalletCoordinator(
      options: [.createRegular, .importRegular, .importWatchOnly, .importTestnet, .signer],
      router: router
    )
    coordinator.didAddWallets = {
      onAddWallets()
    }
    
    addChild(coordinator)
    coordinator.start()
  }
}
