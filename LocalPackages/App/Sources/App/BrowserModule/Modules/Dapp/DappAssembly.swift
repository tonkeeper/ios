import Foundation
import TKCore
import KeeperCore

struct DappAssembly {
  private init() {}
  static func module(dapp: Dapp,
                     analyticsProvider: AnalyticsProvider,
                     deeplinkHandler: @escaping ((_ deeplink: Deeplink) -> Void), messageHandler: DappMessageHandler,
                     wallet: Wallet?)
  -> MVVMModule<DappViewController, Void, Void> {

    let viewModel = DappViewModelImplementation(dapp: dapp, messageHandler: messageHandler, wallet: wallet)
    let viewController = DappViewController(
      viewModel: viewModel,
      deeplinkHandler: deeplinkHandler
    )
    return .init(view: viewController, output: Void(), input: Void())
  }
}
