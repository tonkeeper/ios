import Foundation
import TKCore
import KeeperCore
import TKScreenKit

struct DappAssembly {
  private init() {}
  static func module(dapp: Dapp,
                     webDataStoreProvider: TKWebDataStoreProvider?,
                     analyticsProvider: AnalyticsProvider,
                     deeplinkHandler: @escaping ((_ deeplink: Deeplink) -> Void), messageHandler: DappMessageHandler)
  -> MVVMModule<DappViewController, Void, Void> {

    let viewModel = DappViewModelImplementation(
      dapp: dapp,
      webDataStoreProvider: webDataStoreProvider,
      messageHandler: messageHandler
    )
    let viewController = DappViewController(
      viewModel: viewModel,
      deeplinkHandler: deeplinkHandler
    )
    return .init(view: viewController, output: Void(), input: Void())
  }
}
