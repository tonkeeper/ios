import Foundation
import KeeperCore
import TKLocalize
import TKUIKit
import TonSwift
import UIKit

protocol ManageTokensViewModel: AnyObject {
    var didUpdateSnapshot: ((
        _ snapshot: ManageTokensViewController.Snapshot,
        _ isAnimated: Bool
    ) -> Void)? { get set }
    var didUpdateTitleView: ((TKUINavigationBarTitleView.Model) -> Void)? { get set }

    func viewDidLoad()
    func getItemCellConfiguration(item: ManageTokensListItem) -> TKListItemCell.Configuration?
    func didStartDragging()
    func didStopDragging()
    func movePinnedItem(from: Int, to: Int)
}

enum ManageTokensItemState {
    case pinned
    case unpinned(isHidden: Bool)
}

final class ManageTokensViewModelImplementation: ManageTokensViewModel {
    struct ListModel {
        let snapshot: ManageTokensViewController.Snapshot
        let itemCellConfigurations: [ManageTokensListItem: TKListItemCell.Configuration]
    }

    // MARK: - ManageTokensViewModel

    var didUpdateTitleView: ((TKUINavigationBarTitleView.Model) -> Void)?
    var didUpdateSnapshot: ((ManageTokensViewController.Snapshot, Bool) -> Void)?

    func viewDidLoad() {
        didUpdateTitleView?(
            TKUINavigationBarTitleView.Model(
                title: TKLocales.HomeScreenConfiguration.title
            )
        )

        model.didUpdateState = { [weak self] state in
            guard let self else { return }
            updateQueue.async {
                let listModel = self.handleState(state: state)
                DispatchQueue.main.async {
                    self.listModel = listModel
                    self.didUpdateSnapshot?(listModel.snapshot, false)
                }
            }
        }

        let state = model.getState()
        let listModel = self.handleState(state: state)
        self.listModel = listModel
        self.didUpdateSnapshot?(listModel.snapshot, false)
    }

    func getItemCellConfiguration(item: ManageTokensListItem) -> TKListItemCell.Configuration? {
        listModel.itemCellConfigurations[item]
    }

    func didStartDragging() {
        self.isDragging = true
    }

    func didStopDragging() {
        self.isDragging = false
    }

    func movePinnedItem(from: Int, to: Int) {
        model.movePinnedItem(from: from, to: to)
    }

    // MARK: - State

    private var listModel = ListModel(
        snapshot: ManageTokensViewController.Snapshot(),
        itemCellConfigurations: [:]
    )

    private var isDragging = false

    // MARK: - Dependencies

    private let model: ManageTokensModel
    private let mapper: ManageTokensListMapper
    private let updateQueue: DispatchQueue
    private let configuration: Configuration

    // MARK: - Init

    init(
        model: ManageTokensModel,
        mapper: ManageTokensListMapper,
        updateQueue: DispatchQueue,
        configuration: Configuration
    ) {
        self.model = model
        self.mapper = mapper
        self.updateQueue = updateQueue
        self.configuration = configuration
    }
}

private extension ManageTokensViewModelImplementation {
    func handleState(state: ManageTokensModel.State) -> ListModel {
        var snapshot = ManageTokensViewController.Snapshot()
        var itemCellConfigurations = [ManageTokensListItem: TKListItemCell.Configuration]()

        snapshot.appendSections([.pinned, .allAssets])

        for pinnedItem in state.pinnedItems {
            switch pinnedItem {
            case let .ton(ton):
                let cellConfiguration = mapper.mapTonItem(ton)
                let item = ManageTokensListItem(
                    identifier: ton.id,
                    canReorder: true,
                    accessories: createPinnedItemAccessories(identifier: ton.id)
                )
                itemCellConfigurations[item] = cellConfiguration
                snapshot.appendItems([item], toSection: .pinned)
            case let .jetton(jetton):
                let isNetworkBadgeVisible = model.wallet.isTronTurnOn && jetton.jetton.jettonInfo.isTonUSDT
                let cellConfiguration = mapper.mapJettonItem(
                    jetton,
                    isNetworkBadgeVisible: isNetworkBadgeVisible
                )
                let item = ManageTokensListItem(
                    identifier: jetton.id,
                    canReorder: true,
                    accessories: createPinnedItemAccessories(identifier: jetton.id)
                )
                itemCellConfigurations[item] = cellConfiguration
                snapshot.appendItems([item], toSection: .pinned)
            case let .staking(staking):
                let cellConfiguration = mapper.mapStakingItem(staking)
                let item = ManageTokensListItem(
                    identifier: staking.id,
                    canReorder: true,
                    accessories: createPinnedItemAccessories(identifier: staking.id)
                )
                itemCellConfigurations[item] = cellConfiguration
                snapshot.appendItems([item], toSection: .pinned)
            case let .tronUSDT(model):
                if configuration.flag(\.tronDisabled, network: self.model.wallet.network), model.amount.isZero { continue }

                let cellConfiguration = mapper.mapTronUSDTItem(model)
                let item = ManageTokensListItem(
                    identifier: model.id,
                    canReorder: true,
                    accessories: createPinnedItemAccessories(identifier: model.id)
                )
                itemCellConfigurations[item] = cellConfiguration
                snapshot.appendItems([item], toSection: .pinned)
            }
        }
        for unpinnedItem in state.unpinnedItems {
            switch unpinnedItem.item {
            case let .ton(ton):
                let cellConfiguration = mapper.mapTonItem(ton)
                let item = ManageTokensListItem(
                    identifier: ton.id,
                    canReorder: false,
                    accessories: createUnpinnedItemAccessories(identifier: ton.id, isHidden: unpinnedItem.isHidden)
                )
                itemCellConfigurations[item] = cellConfiguration
                snapshot.appendItems([item], toSection: .allAssets)
            case let .jetton(jetton):
                let cellConfiguration = mapper.mapJettonItem(jetton, isNetworkBadgeVisible: model.wallet.isTronTurnOn)
                let item = ManageTokensListItem(
                    identifier: jetton.id,
                    canReorder: false,
                    accessories: createUnpinnedItemAccessories(identifier: jetton.id, isHidden: unpinnedItem.isHidden)
                )
                itemCellConfigurations[item] = cellConfiguration
                snapshot.appendItems([item], toSection: .allAssets)
            case let .staking(staking):
                let cellConfiguration = mapper.mapStakingItem(staking)
                let item = ManageTokensListItem(
                    identifier: staking.id,
                    canReorder: false,
                    accessories: createUnpinnedItemAccessories(identifier: staking.id, isHidden: unpinnedItem.isHidden)
                )
                itemCellConfigurations[item] = cellConfiguration
                snapshot.appendItems([item], toSection: .allAssets)
            case let .tronUSDT(model):
                if configuration.flag(\.tronDisabled, network: self.model.wallet.network), model.amount.isZero { continue }

                let cellConfiguration = mapper.mapTronUSDTItem(model)
                let item = ManageTokensListItem(
                    identifier: model.id,
                    canReorder: false,
                    accessories: createUnpinnedItemAccessories(identifier: model.id, isHidden: unpinnedItem.isHidden)
                )
                itemCellConfigurations[item] = cellConfiguration
                snapshot.appendItems([item], toSection: .allAssets)
            }
        }

        if #available(iOS 15.0, *) {
            snapshot.reconfigureItems(snapshot.itemIdentifiers)
        } else {
            snapshot.reloadItems(snapshot.itemIdentifiers)
        }

        return ListModel(
            snapshot: snapshot,
            itemCellConfigurations: itemCellConfigurations
        )
    }

    private func createPinnedItemAccessories(identifier: String) -> [TKListItemAccessory] {
        return [
            TKListItemAccessory.icon(
                TKListItemIconAccessoryView.Configuration(
                    icon: .TKUIKit.Icons.Size28.pin,
                    tintColor: .Accent.blue,
                    action: { [weak self] in
                        self?.model.unpinItem(identifier: identifier)
                    }
                )
            ),
            TKListItemAccessory.icon(
                TKListItemIconAccessoryView.Configuration(
                    icon: .TKUIKit.Icons.Size28.reorder,
                    tintColor: .Icon.secondary
                )
            ),
        ]
    }

    private func createUnpinnedItemAccessories(identifier: String, isHidden: Bool) -> [TKListItemAccessory] {
        if isHidden {
            return [.icon(
                TKListItemIconAccessoryView.Configuration(
                    icon: .TKUIKit.Icons.Size28.eyeClosedOutline,
                    tintColor: .Icon.tertiary,
                    action: { [weak self] in
                        self?.model.unhideItem(identifier: identifier)
                    }
                )
            )]
        } else {
            return [
                .icon(
                    TKListItemIconAccessoryView.Configuration(
                        icon: .TKUIKit.Icons.Size28.pin,
                        tintColor: .Icon.tertiary,
                        action: { [weak self] in
                            self?.model.pinItem(identifier: identifier)
                        }
                    )
                ),
                .icon(
                    TKListItemIconAccessoryView.Configuration(
                        icon: .TKUIKit.Icons.Size28.eyeOutline,
                        tintColor: .Accent.blue,
                        action: { [weak self] in
                            self?.model.hideItem(identifier: identifier)
                        }
                    )
                ),
            ]
        }
    }
}
