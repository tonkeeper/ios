import Foundation
import TKCore
import KeeperCore

struct BrowserConnectedAssembly {
  private init() {}
  static func module(keeperCoreAssembly: KeeperCore.MainAssembly)
  -> MVVMModule<BrowserConnectedViewController, BrowserConnectedModuleOutput, Void> {

    let tonConnectStore = keeperCoreAssembly.tonConnectAssembly.tonConnectAppsStore
    let connectedAppsStore = keeperCoreAssembly.storesAssembly.connectedAppsStore(
      tonConnectAppsStore: tonConnectStore
    )
    let viewModel = BrowserConnectedViewModelImplementation(
      walletsStore: keeperCoreAssembly.storesAssembly.walletsStore,
      connectedAppsStore: connectedAppsStore,
      notificationsService: keeperCoreAssembly.servicesAssembly.notificationsService(
        walletNotificationsStore: keeperCoreAssembly.storesAssembly.walletNotificationStore,
        tonConnectAppsStore: keeperCoreAssembly.tonConnectAssembly.tonConnectAppsStore
      ),
      pushTokenProvider: PushNotificationTokenProvider()
    )
    let viewController = BrowserConnectedViewController(
      viewModel: viewModel
    )
    return .init(view: viewController, output: viewModel, input: Void())
  }
}
