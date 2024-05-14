import Foundation
import TKCore
import KeeperCore

struct DappAssembly {
  private init() {}
  static func module(app: PopularApp, messageHandler: DappMessageHandler)
  -> MVVMModule<DappViewController, Void, Void> {

    let viewModel = DappViewModelImplementation(app: app, messageHandler: messageHandler)
    let viewController = DappViewController(
      viewModel: viewModel
    )
    return .init(view: viewController, output: Void(), input: Void())
  }
}
