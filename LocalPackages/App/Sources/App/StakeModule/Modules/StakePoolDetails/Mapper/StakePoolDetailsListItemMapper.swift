import UIKit
import TKUIKit
import KeeperCore

struct StakePoolDetailItem {
  let id: String
  let title: String
  let tag: String?
  let value: String
}

struct StakePoolDetailsListItemMapper {
  func mapStakePool(_ stakePool: StakePool) -> [TKUIListItemCell.Configuration] {
    let detailItems: [StakePoolDetailItem] = [
      StakePoolDetailItem(id: "apy", title: "APY", tag: stakePool.tag, value: "≈ \(stakePool.apy)"),
      StakePoolDetailItem(id: "min", title: "Minimal deposit", tag: nil, value: "\(stakePool.minimumDeposit)")
    ]
    return detailItems.map { mapStakePoolDetailItem($0) }
  }
  
  func mapStakePoolDetailItem(_ item: StakePoolDetailItem) -> TKUIListItemCell.Configuration {
    let id = item.id
    let title = item.title.withTextStyle(.body2, color: .Text.secondary)
    let tagViewModel = makeTagViewModel(item.tag)
    let value = item.value.withTextStyle(.body2, color: .Text.primary)
    
    let contentConfiguration = TKUIListItemContentView.Configuration(
      leftItemConfiguration:
          .init(
            title: title,
            tagViewModel: tagViewModel,
            subtitle: nil,
            description: nil
          ),
      rightItemConfiguration:
          .init(
            value: value,
            subtitle: nil,
            description: nil
          )
    )
    
    let listItemConfiguration = TKUIListItemView.Configuration(
      iconConfiguration: .init(iconConfiguration: .none, alignment: .center),
      contentConfiguration: contentConfiguration,
      accessoryConfiguration: .none
    )
    
    return TKUIListItemCell.Configuration(
      id: id,
      listItemConfiguration: listItemConfiguration,
      selectionClosure: nil
    )
  }
  
  func mapStakePoolLink(_ item: StakePool.Link, selectionClosure: @escaping (() -> Void)) -> IconButtonCell.Configuration {
    let id = "\(UUID().uuidString)_\(item.titledUrl.url.absoluteString)"
    
    let iconButtonModel = IconButttonContentView.Model(
      title: item.titledUrl.title.withTextStyle(.label2, color: .Button.secondaryForeground),
      icon: .image(item.icon),
      iconTint: .Button.secondaryForeground,
      iconSize: CGSize(width: 16, height: 16),
      paddings: IconButttonContentView.Paddings(
        contentPaddingWithIcon: UIEdgeInsets(top: 10, left: 16, bottom: 10, right: 16)
      )
    )
    
    return IconButtonCell.Configuration(
      id: id,
      iconButton: iconButtonModel,
      selectionClosure: selectionClosure
    )
  }
}

private extension  StakePoolDetailsListItemMapper {
  func makeTagViewModel(_ tagText: String?) -> TKUITagView.Configuration? {
    guard let tagText else { return nil }
    return TKUITagView.Configuration(
      text: tagText,
      textColor: .Accent.green,
      backgroundColor: .Accent.green.withAlphaComponent(0.16)
    )
  }
}
