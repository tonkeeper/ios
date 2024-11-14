import UIKit
import TKCore
import KeeperCore

struct RecipientInputAssembly {
  private init() {}
  static func module(wallet: Wallet,
                     keeperCoreMainAssembly: KeeperCore.MainAssembly,
                     coreAssembly: TKCore.CoreAssembly) -> MVVMModule<RecipientInputViewController, RecipientInputModuleOutput, Void> {
    let viewController = RecipientInputViewController(
      wallet: wallet,
      recipientResolver: keeperCoreMainAssembly.loadersAssembly.recipientResolver()
    )
    
    return MVVMModule(
      view: viewController,
      output: viewController,
      input: Void()
    )
  }
}


