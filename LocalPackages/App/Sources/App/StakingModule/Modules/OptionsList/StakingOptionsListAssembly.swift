import Foundation
import TKCore
import KeeperCore
import TonSwift

struct StakingOptionsListAssembly {
  static func module(
    keeperCoreMainAssembly: KeeperCore.MainAssembly,
    listModel: StakingOptionsListModel,
    selectedPoolAddress: Address?
  ) -> MVVMModule<StakingOptionsListViewController, StakingOptionsListModuleOutput, Void> {
    let viewModel = StakingOptionsListViewModelImplementation(
      controller: keeperCoreMainAssembly.stakingOptionsListController(
        listModel: listModel,
        selectedPoolAddress: selectedPoolAddress
      ),
      mapper: .init()
    )
    let viewController = StakingOptionsListViewController(viewModel: viewModel)
    
    return .init(view: viewController, output: viewModel, input: Void())
  }
}
