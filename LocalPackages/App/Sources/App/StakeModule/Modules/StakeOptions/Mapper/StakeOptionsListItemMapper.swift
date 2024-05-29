import UIKit
import TKUIKit
import KeeperCore

struct StakeOptionsListItemMapper {
  func mapLiquidStakingPoolListItem(_ item: StakePool, selectionClosure: @escaping (() -> Void)) -> SelectionCollectionViewCell.Configuration {
    let id = item.id
    let title = item.title.withTextStyle(.label1, color: .Text.primary)
    let tagViewModel = makeTagViewModel(item.tag)
    var subtitle: NSAttributedString?
    if let minimumDeposit = item.minimumDeposit {
      subtitle = createMinimumDepositTitle(minimumDeposit)
    }
    let apyTitle = "APY ≈ \(item.apy)"
    let description = apyTitle.withTextStyle(.body2, color: .Text.secondary)
    
    let iconConfiguration = TKUIListItemIconView.Configuration(
      iconConfiguration:
          .image(
            .init(
              image: .image(item.image),
              tintColor: .clear,
              backgroundColor: .Background.contentTint,
              size: .init(width: 44, height: 44),
              cornerRadius: 22
            )
          ),
      alignment: .center
    )
    
    let contentConfiguration = TKUIListItemContentView.Configuration(
      leftItemConfiguration:
          .init(
            title: title,
            tagViewModel: tagViewModel,
            subtitle: subtitle,
            description: description
          ),
      rightItemConfiguration: nil
    )
    
    let listItemConfiguration = TKUIListItemView.Configuration(
      iconConfiguration: iconConfiguration,
      contentConfiguration: contentConfiguration,
      accessoryConfiguration: .none
    )
    
    return SelectionCollectionViewCell.Configuration(
      id: id,
      listItemConfiguration: listItemConfiguration,
      accesoryConfiguration: .init(accessoryType: .radioButton),
      accesoryAlignment: .right,
      selectionClosure: selectionClosure
    )
  }
  
  func mapOtherPoolListItem(_ item: StakePoolList, selectionClosure: @escaping (() -> Void)) -> TKUIListItemCell.Configuration {
    let id = item.id
    let title = item.title.withTextStyle(.label1, color: .Text.primary)
    let tagViewModel = makeTagViewModel(item.tag)
    let subtitle = createMinimumDepositTitle(item.minimumDeposit)
    let description = item.description.withTextStyle(.body2, color: .Text.secondary)
    
    let iconConfiguration = TKUIListItemIconView.Configuration(
      iconConfiguration:
          .image(
            .init(
              image: .image(item.image),
              tintColor: .clear,
              backgroundColor: .Background.contentTint,
              size: .init(width: 44, height: 44),
              cornerRadius: 22
            )
          ),
      alignment: .center
    )
    
    let contentConfiguration = TKUIListItemContentView.Configuration(
      leftItemConfiguration:
          .init(
            title: title,
            tagViewModel: tagViewModel,
            subtitle: subtitle,
            description: description
          ),
      rightItemConfiguration: nil
    )
    
    let accessoryImageConfiguration = TKUIListItemImageAccessoryView.Configuration(
      image: .TKUIKit.Icons.Size16.chevronRight,
      tintColor: .Icon.tertiary,
      padding: .zero
    )
    
    let listItemConfiguration = TKUIListItemView.Configuration(
      iconConfiguration: iconConfiguration,
      contentConfiguration: contentConfiguration,
      accessoryConfiguration: .image(accessoryImageConfiguration)
    )
    
    return TKUIListItemCell.Configuration(
      id: id,
      listItemConfiguration: listItemConfiguration,
      selectionClosure: selectionClosure
    )
  }
}

private extension  StakeOptionsListItemMapper {
  func makeTagViewModel(_ tagText: String?) -> TKUITagView.Configuration? {
    guard let tagText else { return nil }
    return TKUITagView.Configuration(
      text: tagText,
      textColor: .Accent.green,
      backgroundColor: .Accent.green.withAlphaComponent(0.16)
    )
  }
  
  func createMinimumDepositTitle(_ minimumDeposit: String) -> NSAttributedString {
    "Minimum deposit \(minimumDeposit).".withTextStyle(.body2, color: .Text.secondary)
  }
}
