import UIKit
import TKUIKit
import TKCoordinator
import TKCore
import KeeperCore
import WidgetKit

public final class AppCoordinator: RouterCoordinator<WindowRouter> {
  
  let coreAssembly: TKCore.CoreAssembly
  let keeperCoreAssembly: KeeperCore.Assembly
  
  private let appStateTracker: AppStateTracker
  
  private weak var rootCoordinator: RootCoordinator?
  
  public init(router: WindowRouter,
              coreAssembly: TKCore.CoreAssembly) {
    self.coreAssembly = coreAssembly
    self.keeperCoreAssembly = KeeperCore.Assembly(
      dependencies: Assembly.Dependencies(
        cacheURL: coreAssembly.cacheURL,
        sharedCacheURL: coreAssembly.sharedCacheURL,
        appInfoProvider: coreAssembly.appInfoProvider
      )
    )
    self.appStateTracker = coreAssembly.appStateTracker
    super.init(router: router)
  }
  
  public override func start(deeplink: CoordinatorDeeplink? = nil) {
    var settingsRepository = keeperCoreAssembly.repositoriesAssembly.settingsRepository()
    if settingsRepository.isFirstRun {
      settingsRepository.isFirstRun = false
      settingsRepository.seed = UUID().uuidString
    }
    
    openRoot(deeplink: deeplink)
    
    appStateTracker.addObserver(self)
  }
  
  public override func handleDeeplink(deeplink: CoordinatorDeeplink?) -> Bool {
    guard let rootCoordinator else { return false }
    return rootCoordinator.handleDeeplink(deeplink: deeplink)
  }
}

private extension AppCoordinator {
  
  func openRoot(deeplink: TKCoordinator.CoordinatorDeeplink? = nil) {
    let rootCoordinator = RootCoordinator(
      router: ViewControllerRouter(rootViewController: UIViewController()),
      dependencies: RootCoordinator.Dependencies(
        coreAssembly: coreAssembly,
        keeperCoreRootAssembly: keeperCoreAssembly.rootAssembly()
      )
    )
    self.router.window.rootViewController = rootCoordinator.router.rootViewController
    
    self.rootCoordinator = rootCoordinator
    
    addChild(rootCoordinator)
    rootCoordinator.start(deeplink: deeplink)
  }
}

extension AppCoordinator: AppStateTrackerObserver {
  public func didUpdateState(_ state: AppStateTracker.State) {
    switch state {
    case .resign:
      WidgetCenter.shared.reloadAllTimelines()
    default:
      break
    }
  }
}
