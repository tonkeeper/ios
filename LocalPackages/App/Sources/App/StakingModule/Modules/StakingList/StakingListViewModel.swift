import BigInt
import KeeperCore
import TKLocalize
import TKUIKit
import UIKit

protocol StakingListModuleOutput: AnyObject {
    var didSelectPool: ((StakingListPool) -> Void)? { get set }
    var didSelectGroup: ((StakingListGroup) -> Void)? { get set }
    var didChoosePool: ((StakingListPool) -> Void)? { get set }
    var didClose: (() -> Void)? { get set }
}

protocol StakingListViewModel: AnyObject {
    var title: String { get }
    var didUpdateSnapshot: ((StakingList.Snapshot) -> Void)? { get set }

    func viewDidLoad()
    func didTapCloseButton()
}

struct StakingListModel {
    let title: String
    let sections: [StakingListSection]
    let selectedPool: StackingPoolInfo?
}

struct StakingListSection {
    let title: String?
    let items: [StakingListItem]
}

struct StakingListGroup {
    let name: String
    let image: UIImage
    let apy: Decimal
    let minAmount: BigUInt
    let isMaxAPY: Bool
    let items: [StakingListPool]
}

struct StakingListPool {
    let pool: StackingPoolInfo
    let isMaxAPY: Bool
}

enum StakingListItem {
    case pool(StakingListPool)
    case group(StakingListGroup)
}

final class StakingListViewModelImplementation: StakingListViewModel, StakingListModuleOutput {
    var didSelectPool: ((StakingListPool) -> Void)?
    var didSelectGroup: ((StakingListGroup) -> Void)?
    var didChoosePool: ((StakingListPool) -> Void)?
    var didClose: (() -> Void)?

    // MARK: - StakingListViewModel

    var title: String {
        model.title
    }

    var didUpdateSnapshot: ((StakingList.Snapshot) -> Void)?

    func viewDidLoad() {
        let snapshot = createSnapshot()
        didUpdateSnapshot?(snapshot)
    }

    func didTapCloseButton() {
        didClose?()
    }

    private let model: StakingListModel
    private let amountFormatter: AmountFormatter

    init(
        model: StakingListModel,
        amountFormatter: AmountFormatter
    ) {
        self.model = model
        self.amountFormatter = amountFormatter
    }
}

private extension StakingListViewModelImplementation {
    func createSnapshot() -> StakingList.Snapshot {
        var snapshot = StakingList.Snapshot()

        for section in model.sections {
            let snapshotSection = StakingList.Section(
                id: UUID().uuidString,
                title: section.title
            )
            snapshot.appendSections([snapshotSection])
            let items = section.items.map { mapItem($0) }
            snapshot.appendItems(items, toSection: snapshotSection)
        }

        return snapshot
    }

    func mapItem(_ item: StakingListItem) -> StakingList.Item {
        switch item {
        case let .pool(stakingListPool):
            return mapPool(stakingListPool)
        case let .group(stakingListGroup):
            return mapGroup(stakingListGroup)
        }
    }

    func mapPool(_ pool: StakingListPool) -> StakingList.Item {
        let tagText: String? = pool.isMaxAPY ? .mostProfitableTag : nil
        let percentFormatted = amountFormatter.format(
            decimal: pool.pool.apy,
            accessory: .none,
            style: .compact
        )
        let percentDescription = "\(String.apy)\u{00a0}≈\u{00a0}\(percentFormatted)%"
        let minimumFormatted = amountFormatter.format(
            amount: BigUInt(
                UInt64(pool.pool.minStake)
            ),
            fractionDigits: TonInfo.fractionDigits,
            accessory: .symbol(TonInfo.symbol),
            isNegative: false,
            style: .compact
        )
        let minimumDescription = TKLocales.StakingList.minimumDepositDescription(minimumFormatted)
        let description = "\(minimumDescription). \(percentDescription)"

        let configuration = StakingList.mapListItemConfiguration(
            title: pool.pool.name,
            image: .image(pool.pool.icon),
            tag: tagText,
            caption: description
        )

        return StakingList.Item(
            identifier: pool.pool.address.toRaw(),
            configuration: configuration,
            accessory: .radioButton(
                TKListItemRadioButtonAccessoryView.Configuration(
                    isSelected: pool.pool.address == model.selectedPool?.address,
                    size: 24,
                    action: { [weak self] _ in
                        guard self?.model.selectedPool?.address != pool.pool.address else {
                            return
                        }
                        self?.didChoosePool?(pool)
                    }
                )
            ),
            selectionHandler: { [weak self] in
                self?.didSelectPool?(pool)
            }
        )
    }

    func mapGroup(_ group: StakingListGroup) -> StakingList.Item {
        let percentFormatted = amountFormatter.format(
            decimal: group.apy,
            accessory: .none,
            style: .compact
        )
        let subtitle = "\(String.apy) ≈ \(percentFormatted)%"
        let tagText: String? = group.isMaxAPY ? .mostProfitableTag : nil

        let configuration = StakingList.mapListItemConfiguration(
            title: group.name,
            image: .image(group.image),
            tag: tagText,
            caption: subtitle
        )

        return StakingList.Item(
            identifier: UUID().uuidString,
            configuration: configuration,
            accessory: .chevron,
            selectionHandler: { [weak self] in
                self?.didSelectGroup?(group)
            }
        )
    }
}

private extension String {
    static let mostProfitableTag = TKLocales.StakingList.maxApy
    static let apy = TKLocales.StakingList.apy
}
