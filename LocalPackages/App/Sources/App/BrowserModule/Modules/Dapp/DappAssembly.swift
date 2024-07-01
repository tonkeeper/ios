import Foundation
import TKCore
import KeeperCore

struct DappAssembly {
  private init() {}
  static func module(dapp: Dapp, analyticsProvider: AnalyticsProvider, messageHandler: DappMessageHandler)
  -> MVVMModule<DappViewController, Void, Void> {

    let viewModel = DappViewModelImplementation(dapp: dapp, messageHandler: messageHandler)
    let viewController = DappViewController(
      viewModel: viewModel,
      analyticsProvider: analyticsProvider
    )
    return .init(view: viewController, output: Void(), input: Void())
  }
}
