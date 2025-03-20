import Foundation
import TKCore
import KeeperCore

@MainActor
struct SignDataAssembly {
  private init() {}
  static func module(
    wallet: Wallet,
    dappUrl: String,
    signRequest: TonConnect.SignDataRequest,
    resultHandler: SignDataResultHandler
  ) -> MVVMModule<SignDataViewController, SignDataModuleOutput, Void> {
    let viewModel = SignDataViewModelImplementation(
      wallet: wallet,
      dappUrl: dappUrl,
      signRequest: signRequest,
      resultHandler: resultHandler
    )
    
    let viewController = SignDataViewController(viewModel: viewModel)
    return MVVMModule(view: viewController, output: viewModel, input: Void())
  }
}
