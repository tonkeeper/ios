import UIKit
import TKCore
import KeeperCore

struct CollectibleDetailsAssembly {
  static func module(collectibleDetailsController: CollectibleDetailsController,
                     urlOpener: URLOpener,
                     output: CollectibleDetailsModuleOutput?) -> (CollectibleDetailsViewController, CollectibleDetailsModuleInput) {
    let presenter = CollectibleDetailsPresenter(
      collectibleDetailsController: collectibleDetailsController,
      urlOpener: urlOpener
    )
    presenter.output = output
    
    let viewController = CollectibleDetailsViewController(presenter: presenter)
    presenter.viewInput = viewController
    
    return (viewController, presenter)
  }
}
