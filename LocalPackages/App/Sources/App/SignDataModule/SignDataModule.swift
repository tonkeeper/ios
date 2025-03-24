import TKUIKit
import TKCoordinator
import TKCore
import KeeperCore

public protocol SignDataResultHandler {
  func didSign(signedData: String)
  func didFail(error: Swift.Error)
  func didCancel()
}

@MainActor
struct SignDataModule {
  private let dependencies: Dependencies
  init(dependencies: Dependencies) {
    self.dependencies = dependencies
  }
  
  func signDataModule(
    wallet: Wallet,
    dappUrl: String,
    signRequest: TonConnect.SignDataRequest,
    resultHandler: SignDataResultHandler
  ) -> MVVMModule<SignDataViewController, SignDataModuleOutput, SignDataModuleInput> {
    return SignDataAssembly.module(
      wallet: wallet,
      dappUrl: dappUrl,
      signRequest: signRequest,
      resultHandler: resultHandler
    )
  }
}

extension SignDataModule {
  struct Dependencies {
    let coreAssembly: TKCore.CoreAssembly
    let keeperCoreMainAssembly: KeeperCore.MainAssembly
    
    public init(coreAssembly: TKCore.CoreAssembly,
                keeperCoreMainAssembly: KeeperCore.MainAssembly) {
      self.coreAssembly = coreAssembly
      self.keeperCoreMainAssembly = keeperCoreMainAssembly
    }
  }
}
