import UIKit
import TKCoordinator
import TKCore
import TKUIKit
import KeeperCore
import TonSwift
import TKLocalize
import URKit
import TonTransport

enum SignDataSignError: Swift.Error {
  case incorrectWalletKind
  case cancelled
  case failedToSign(Swift.Error?)
}

final class SignDataSignCoordinator: RouterCoordinator<ViewControllerRouter> {
  
  enum ExtenalSignError: Swift.Error {
    case cancelled
  }
  
  enum Result {
    case signed(String)
    case failed(SignDataSignError)
    case cancel
  }
  
  var didFail: ((SignDataSignError) -> Void)?
  var didSign: ((String) -> Void)?
  var didCancel: (() -> Void)?
  
  var externalSignHandler: ((Data?) -> Void)?
  
  private let wallet: Wallet
  private let dappUrl: String
  private let request: TonConnect.SignDataRequest
  private let keeperCoreMainAssembly: KeeperCore.MainAssembly
  private let coreAssembly: TKCore.CoreAssembly
  
  init(router: ViewControllerRouter,
       wallet: Wallet,
       dappUrl: String,
       request: TonConnect.SignDataRequest,
       keeperCoreMainAssembly: KeeperCore.MainAssembly,
       coreAssembly: TKCore.CoreAssembly) {
    self.wallet = wallet
    self.request = request
    self.keeperCoreMainAssembly = keeperCoreMainAssembly
    self.dappUrl = dappUrl
    self.coreAssembly = coreAssembly
    super.init(router: router)
  }
  
  override func start() {
    handleSign()
  }
  
  func handleSign(parentCoordinator: Coordinator) async -> Result {
    return await Task<SignDataSignCoordinator.Result, Never> { @MainActor in
      return await withCheckedContinuation { [weak parentCoordinator] (continuation: CheckedContinuation<SignDataSignCoordinator.Result, Never>) in
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

private extension SignDataSignCoordinator {
  func handleSign() {
    switch wallet.identity.kind {
    case .Regular:
      handleRegularSign()
    case .SignerDevice(_, _), .Signer(_, _), .Watchonly, .Ledger(_, _, _), .Keystone(_, _, _, _), .Lockup(_, _):
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
      onInput: { [weak self, wallet, keeperCoreMainAssembly, dappUrl, request] passcode in
        guard let self else { return }
        Task {
          do {
            let signed = try await SignDataSigner(request, wallet: wallet, mnemonicsRepository: keeperCoreMainAssembly.secureAssembly.mnemonicsRepository(), dappUrl: dappUrl, passcode: passcode).sign()
            
        
            let jSONEncoder = JSONEncoder()
            
            let jsonData = try jSONEncoder.encode(signed)
            
            self.didSign?(String(data: jsonData, encoding: .utf8)!)
          } catch {
            self.didFail?(.failedToSign(error))
          }
        }
      }
    )
  }
}
