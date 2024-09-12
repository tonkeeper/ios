import UIKit
import TKUIKit
import KeeperCore
import BigInt
import TKLocalize

protocol StakingListModuleOutput: AnyObject {
  var didSelectPool: ((StakingListPool) -> Void)? { get set }
  var didSelectGroup: ((StakingListGroup) -> Void)? { get set }
}

protocol StakingListViewModel: AnyObject {
  var title: String { get }
  var didUpdateSnapshot: ((NSDiffableDataSourceSnapshot<StakingListCollectionSection, TKUIListItemCell.Configuration>) -> Void)? { get set }
  
  func viewDidLoad()
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
  
  // MARK: - StakingListViewModel
  
  var title: String {
    model.title
  }
  
  var didUpdateSnapshot: ((NSDiffableDataSourceSnapshot<StakingListCollectionSection, TKUIListItemCell.Configuration>) -> Void)?
  
  func viewDidLoad() {
    let snapshot = createSnapshot()
    didUpdateSnapshot?(snapshot)
  }

  private let model: StakingListModel
  private let decimalFormatter: DecimalAmountFormatter
  private let amountFormatter: AmountFormatter
  
  init(model: StakingListModel,
       decimalFormatter: DecimalAmountFormatter,
       amountFormatter: AmountFormatter) {
    self.model = model
    self.decimalFormatter = decimalFormatter
    self.amountFormatter = amountFormatter
  }
}

private extension StakingListViewModelImplementation {
  func createSnapshot() -> NSDiffableDataSourceSnapshot<StakingListCollectionSection, TKUIListItemCell.Configuration> {
    var snapshot = NSDiffableDataSourceSnapshot<StakingListCollectionSection, TKUIListItemCell.Configuration>()
    
    for section in model.sections {
      let listSection = StakingListCollectionSection(uuid: UUID(), title: section.title)
      snapshot.appendSections([listSection])
      let items = section.items.map { mapItem($0) }
      snapshot.appendItems(items, toSection: listSection)
    }
    
    return snapshot
  }
  
  func mapItem(_ item: StakingListItem) -> TKUIListItemCell.Configuration {
    switch item {
    case .pool(let stakingListPool):
      return mapPool(stakingListPool)
    case .group(let stakingListGroup):
      return mapGroup(stakingListGroup)
    }
  }
  
  func mapPool(_ pool: StakingListPool) -> TKUIListItemCell.Configuration {
    let tagText: String? = pool.isMaxAPY ? .mostProfitableTag : nil
    let percentFormatted = decimalFormatter.format(amount: pool.pool.apy, maximumFractionDigits: 2)
    let percentDescription = "\(String.apy) ≈ \(percentFormatted)%"
    let minimumFormatted = amountFormatter.formatAmount(
      BigUInt(
        UInt64(pool.pool.minStake)
      ),
      fractionDigits: TonInfo.fractionDigits,
      maximumFractionDigits: 2,
      symbol: TonInfo.symbol
    )
    let minimumDescription = TKLocales.StakingList.minimum_deposit_description(minimumFormatted)

    let description = "\(minimumDescription)\n\(percentDescription)"
    
    let title = pool.pool.name.withTextStyle(
      .label1,
      color: .Text.primary,
      alignment: .left,
      lineBreakMode: .byTruncatingTail
    )
    
    var tagViewModel: TKUITagView.Configuration?
    if let tagText {
      tagViewModel = TKUITagView.Configuration(
        text: tagText,
        textColor: .Accent.green,
        backgroundColor: .Accent.green.withAlphaComponent(0.16)
      )
    }
    
    let itemView = TKUIListItemView.Configuration(
      iconConfiguration: TKUIListItemIconView.Configuration(
        iconConfiguration: .image(
          TKUIListItemImageIconView.Configuration(
            image: TKUIListItemImageIconView.Configuration.Image.image(pool.pool.implementation.icon),
            tintColor: .clear,
            backgroundColor: .clear,
            size: CGSize(width: 44, height: 44),
            cornerRadius: 22
          )
        ),
        alignment: .center
      ),
      contentConfiguration: TKUIListItemContentView.Configuration(
        leftItemConfiguration: TKUIListItemContentLeftItem.Configuration(
          title: title,
          tagViewModel: tagViewModel,
          subtitle: nil,
          description: description.withTextStyle(
            .body2,
            color: .Text.secondary,
            alignment: .left,
            lineBreakMode: .byTruncatingTail
          )
        ),
        rightItemConfiguration: nil
      ),
      accessoryConfiguration: .radioButton(
        TKUIListItemRadioButtonAccessoryView.Configuration(
          isSelected: pool.pool.address == model.selectedPool?.address,
          size: 24,
          handler: { _ in
            
          }
        )
      )
    )
    
    return TKUIListItemCell.Configuration(
      id: pool.pool.address.toRaw(),
      listItemConfiguration: itemView,
      isHighlightable: true,
      selectionClosure: { [weak self] in
        self?.didSelectPool?(pool)
      }
    )
  }
  
  func mapGroup(_ group: StakingListGroup) -> TKUIListItemCell.Configuration {
    let percentFormatted = decimalFormatter.format(amount: group.apy, maximumFractionDigits: 2)
    let subtitle = "\(String.apy) ≈ \(percentFormatted)%"
    
    let title = group.name.withTextStyle(
      .label1,
      color: .Text.primary,
      alignment: .left,
      lineBreakMode: .byTruncatingTail
    )
    
    let itemView = TKUIListItemView.Configuration(
      iconConfiguration: TKUIListItemIconView.Configuration(
        iconConfiguration: .image(
          TKUIListItemImageIconView.Configuration(
            image: TKUIListItemImageIconView.Configuration.Image.image(group.image),
            tintColor: .clear,
            backgroundColor: .clear,
            size: CGSize(width: 44, height: 44),
            cornerRadius: 22
          )
        ),
        alignment: .center
      ),
      contentConfiguration: TKUIListItemContentView.Configuration(
        leftItemConfiguration: TKUIListItemContentLeftItem.Configuration(
          title: title,
          tagViewModel: nil,
          subtitle: subtitle.withTextStyle(
            .body2,
            color: .Text.secondary,
            alignment: .left,
            lineBreakMode: .byTruncatingTail
          ),
          description: nil
        ),
        rightItemConfiguration: nil
      ),
      accessoryConfiguration: .image(
        TKUIListItemImageAccessoryView.Configuration(
          image: .TKUIKit.Icons.Size16.chevronRight,
          tintColor: .Icon.tertiary,
          padding: .zero
        )
      )
    )
    
    return TKUIListItemCell.Configuration(
      id: UUID().uuidString,
      listItemConfiguration: itemView,
      isHighlightable: true,
      selectionClosure: { [weak self] in
        self?.didSelectGroup?(group)
      }
    )
  }
}

private extension String {
  static let mostProfitableTag = TKLocales.StakingList.max_apy
  static let apy = TKLocales.StakingList.apy
}
