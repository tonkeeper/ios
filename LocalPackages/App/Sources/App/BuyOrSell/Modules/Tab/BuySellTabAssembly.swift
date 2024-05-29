import Foundation
import TKCore
import KeeperCore

struct BuySellTabAssembly {
  private init() {}
    static func module(
        buyViewController: BuySellViewController,
        sellViewController: BuySellViewController
    ) -> MVVMModule<BuySellTabViewController, Void, Void> {
    let viewController = BuySellTabViewController(
        buyViewController: buyViewController,
        sellViewController: sellViewController
    )
    return .init(view: viewController, output: (), input: ())
  }
}
