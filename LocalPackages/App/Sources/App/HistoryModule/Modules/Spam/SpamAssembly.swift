import Foundation
import KeeperCore
import TKCore

struct SpamAssembly {
    private init() {}
    static func module(historyListViewController: HistoryListViewController)
        -> MVVMModule<SpamViewController, Void, Void>
    {
        let viewController = SpamViewController(
            historyListViewController: historyListViewController
        )
        return .init(view: viewController, output: (), input: ())
    }
}
