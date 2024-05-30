import UIKit
import KeeperCore
import TKCoordinator
import TKUIKit
import TKCore
import TonSwift

enum SignTransactionConfirmationCoordinatorConfirmatorError: Swift.Error {
  case failedToSign
}

protocol SignTransactionConfirmationCoordinatorConfirmator {
  func confirm(wallet: Wallet, signClosure: (WalletTransfer) async throws -> Data?) async throws
  func cancel(wallet: Wallet) async
}

struct DefaultTonConnectSignTransactionConfirmationCoordinatorConfirmator: SignTransactionConfirmationCoordinatorConfirmator {
  private let app: TonConnectApp
  private let appRequest: TonConnect.AppRequest
  private let sendService: SendService
  private let tonConnectService: TonConnectService
  
  init(app: TonConnectApp,
       appRequest: TonConnect.AppRequest,
       sendService: SendService,
       tonConnectService: TonConnectService) {
    self.app = app
    self.appRequest = appRequest
    self.sendService = sendService
    self.tonConnectService = tonConnectService
  }
  
  func confirm(wallet: Wallet, signClosure: (WalletTransfer) async throws -> Data?) async throws {
    guard let parameters = appRequest.params.first else { return }
    let seqno = try await sendService.loadSeqno(wallet: wallet)
    let timeout = await sendService.getTimeoutSafely(wallet: wallet)

    let boc = try await tonConnectService.createConfirmTransactionBoc(
      wallet: wallet,
      seqno: seqno,
      timeout: timeout,
      parameters: parameters,
      signClosure: { walletTranfer in
        guard let signedData = try await signClosure(walletTranfer) else {
          throw SignTransactionConfirmationCoordinatorConfirmatorError.failedToSign
        }
        return signedData
      }
    )
    
    try await sendService.sendTransaction(boc: boc, wallet: wallet)
    try await tonConnectService.confirmRequest(boc: boc, appRequest: appRequest, app: app)
  }
  
  func cancel(wallet: Wallet) async {
    try? await tonConnectService.cancelRequest(appRequest: appRequest, app: app)
  }
}

struct BridgeTonConnectSignTransactionConfirmationCoordinatorConfirmator: SignTransactionConfirmationCoordinatorConfirmator {
  private let appRequest: TonConnect.AppRequest
  private let sendService: SendService
  private let tonConnectService: TonConnectService
  private let connectionResponseHandler: (TonConnectAppsStore.SendTransactionResult) -> Void
  
  init(appRequest: TonConnect.AppRequest,
       sendService: SendService,
       tonConnectService: TonConnectService,
       connectionResponseHandler: @escaping (TonConnectAppsStore.SendTransactionResult) -> Void) {
    self.appRequest = appRequest
    self.sendService = sendService
    self.tonConnectService = tonConnectService
    self.connectionResponseHandler = connectionResponseHandler
  }
  
  func confirm(wallet: Wallet, signClosure: (WalletTransfer) async throws -> Data?) async throws {
    guard let parameters = appRequest.params.first else { return }
    do {
      let seqno = try await sendService.loadSeqno(wallet: wallet)
      let timeout = await sendService.getTimeoutSafely(wallet: wallet)
      let boc = try await tonConnectService.createConfirmTransactionBoc(
        wallet: wallet,
        seqno: seqno,
        timeout: timeout,
        parameters: parameters,
        signClosure: { walletTranfer in
          guard let signedData = try await signClosure(walletTranfer) else {
            throw SignTransactionConfirmationCoordinatorConfirmatorError.failedToSign
          }
          return signedData
        }
      )
      
      try await sendService.sendTransaction(boc: boc, wallet: wallet)
      let sendTransactionResponse = TonConnect.SendTransactionResponse.success(
        .init(result: boc,
              id: appRequest.id)
      )
      let response = try JSONEncoder().encode(sendTransactionResponse)
      connectionResponseHandler(.response(response))
    } catch {
      connectionResponseHandler(.error(.unknownError))
    }
  }
  
  func cancel(wallet: Wallet) async {
    connectionResponseHandler(.error(.userDeclinedTransaction))
  }
}

struct StonfiSwapSignTransactionConfirmationCoordinatorConfirmator: SignTransactionConfirmationCoordinatorConfirmator {
  private let signRequest: SendTransactionSignRequest
  private let sendService: SendService
  private let tonConnectService: TonConnectService
  private let responseHandler: (SendTransactionSignResult) -> Void
  
  init(signRequest: SendTransactionSignRequest,
       sendService: SendService,
       tonConnectService: TonConnectService,
       responseHandler: @escaping (SendTransactionSignResult) -> Void) {
    self.signRequest = signRequest
    self.sendService = sendService
    self.tonConnectService = tonConnectService
    self.responseHandler = responseHandler
  }
  
  func confirm(wallet: KeeperCore.Wallet, signClosure: (WalletTransfer) async throws -> Data?) async throws {
    guard let parameters = signRequest.params.first else { return }
    let seqno = try await sendService.loadSeqno(wallet: wallet)
    let timeout = await sendService.getTimeoutSafely(wallet: wallet)
    let boc = try await tonConnectService.createConfirmTransactionBoc(
      wallet: wallet,
      seqno: seqno,
      timeout: timeout,
      parameters: parameters,
      signClosure: { walletTranfer in
        guard let signedData = try await signClosure(walletTranfer) else {
          throw SignTransactionConfirmationCoordinatorConfirmatorError.failedToSign
        }
        return signedData
      }
    )
    
    try await sendService.sendTransaction(boc: boc, wallet: wallet)
    responseHandler(.response(boc))
  }
  
  func cancel(wallet: KeeperCore.Wallet) async {
    responseHandler(.error(.userDeclinedTransaction))
  }
}

final class SignTransactionConfirmationCoordinator: RouterCoordinator<WindowRouter> {
  
  enum Error: Swift.Error {
    case failedToSign
  }
  
  var didCancel: (() -> Void)?
  var didConfirm: (() -> Void)?
  
  private weak var walletTransferSignCoordinator: WalletTransferSignCoordinator?
  
  private let wallet: Wallet
  private let confirmator: SignTransactionConfirmationCoordinatorConfirmator
  private let confirmTransactionController: ConfirmTransactionController
  private let keeperCoreMainAssembly: KeeperCore.MainAssembly
  private let coreAssembly: TKCore.CoreAssembly
  
  init(router: WindowRouter,
       wallet: Wallet,
       confirmator: SignTransactionConfirmationCoordinatorConfirmator,
       confirmTransactionController: ConfirmTransactionController,
       keeperCoreMainAssembly: KeeperCore.MainAssembly,
       coreAssembly: TKCore.CoreAssembly) {
    self.wallet = wallet
    self.confirmator = confirmator
    self.confirmTransactionController = confirmTransactionController
    self.keeperCoreMainAssembly = keeperCoreMainAssembly
    self.coreAssembly = coreAssembly
    super.init(router: router)
  }
  
  override func start() {
    ToastPresenter.showToast(configuration: .loading)
    Task {
      do {
        let model = try await confirmTransactionController.createRequestModel()
        await MainActor.run {
          ToastPresenter.hideAll()
          openConfirmation(model: model)
        }
      } catch {
        await MainActor.run {
          ToastPresenter.hideAll()
        }
      }
    }
  }
}

private extension SignTransactionConfirmationCoordinator {
  func openConfirmation(model: ConfirmTransactionModel) {
    let rootViewController = UIViewController()
    router.window.rootViewController = rootViewController
    router.window.makeKeyAndVisible()
    
    let keyWindow = UIApplication.keyWindow
    
    let module = TonConnectConfirmationAssembly.module(
      model: model,
      historyEventMapper: HistoryEventMapper(accountEventActionContentProvider: TonConnectConfirmationAccountEventActionContentProvider())
    )
    
    let bottomSheetViewController = TKBottomSheetViewController(contentViewController: module.view)
    
    bottomSheetViewController.didClose = { [weak self] isInteractivly in
      guard let self else { return }
      guard isInteractivly else { return }
      keyWindow?.makeKeyAndVisible()
      self.didCancel?()
      Task {
        await self.confirmator.cancel(wallet: self.wallet)
      }
    }
    
    module.output.didTapCancelButton = { [weak self, weak bottomSheetViewController] in
      guard let self else { return }
      Task {
        await self.confirmator.cancel(wallet: self.wallet)
      }
      bottomSheetViewController?.dismiss(completion: { [weak self] in
        self?.didCancel?()
      })
    }
    
    module.output.didTapConfirmButton = { [weak self, weak bottomSheetViewController, wallet] in
      //      guard let bottomSheetViewController, let self else { return false }
      do {
        try await self?.confirmator.confirm(wallet: wallet) { walletTransfer in
          guard let self, let bottomSheetViewController else { throw Error.failedToSign }
          return try await self.performSign(walletTransfer: walletTransfer, wallet: wallet, fromViewController: bottomSheetViewController)
        }
        return true
      } catch {
        return false
      }
    }
    
    module.output.didConfirm = { [weak self, weak bottomSheetViewController] in
      bottomSheetViewController?.dismiss(completion: { [weak self] in
        self?.didConfirm?()
      })
    }
    
    bottomSheetViewController.present(fromViewController: rootViewController)
  }
  
  func performSign(walletTransfer: WalletTransfer, wallet: Wallet, fromViewController: UIViewController) async throws -> Data {
    let coordinator = await WalletTransferSignCoordinator(
      router: ViewControllerRouter(rootViewController: fromViewController),
      wallet: wallet,
      walletTransfer: walletTransfer,
      keeperCoreMainAssembly: keeperCoreMainAssembly)
    
    self.walletTransferSignCoordinator = coordinator
    
    let result = await coordinator.handleSign(parentCoordinator: self)
    
    switch result {
    case .signed(let data):
      return data
    case .cancel:
      throw Error.failedToSign
    case .failed(let error):
      throw error
    }
  }
}
