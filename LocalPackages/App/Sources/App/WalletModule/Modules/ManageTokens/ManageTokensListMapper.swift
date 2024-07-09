import UIKit
import TKUIKit
import TKLocalize
import TKCore
import KeeperCore
import BigInt

struct ManageTokensListMapper {
  
  let imageLoader = ImageLoader()
  
  private let amountFormatter: AmountFormatter
  
  init(amountFormatter: AmountFormatter) {
    self.amountFormatter = amountFormatter
  }
  
  func mapTonItem(_ item: BalanceTonItemModel) -> TKUIListItemCell.Configuration {
    let amount = amountFormatter.formatAmount(
      item.amount,
      fractionDigits: item.fractionalDigits,
      maximumFractionDigits: 2,
      symbol: TonInfo.symbol
    ).withTextStyle(.body2, color: .Text.secondary, alignment: .left, lineBreakMode: .byTruncatingTail)
    
    let listItemConfiguration = TKUIListItemView.Configuration(
      iconConfiguration: .tonConfiguration(imageLoader: imageLoader),
      contentConfiguration: TKUIListItemContentView.Configuration(
        leftItemConfiguration: .tonConfiguration(subtitle: amount),
        rightItemConfiguration: nil
      ),
      accessoryConfiguration: .none
    )
    
    return TKUIListItemCell.Configuration(
      id: "",
      listItemConfiguration: listItemConfiguration,
      isHighlightable: false,
      selectionClosure: nil
    )
  }
  
  func mapJettonItem(_ item: BalanceJettonItemModel) -> TKUIListItemCell.Configuration {
    let amount = amountFormatter.formatAmount(
      item.amount,
      fractionDigits: item.fractionalDigits,
      maximumFractionDigits: 2,
      symbol: item.jetton.jettonInfo.symbol
    ).withTextStyle(.body2, color: .Text.secondary, alignment: .left, lineBreakMode: .byTruncatingTail)
    
    let listItemConfiguration = TKUIListItemView.Configuration(
      iconConfiguration: .configuration(jettonInfo: item.jetton.jettonInfo, imageLoader: imageLoader),
      contentConfiguration: TKUIListItemContentView.Configuration(
        leftItemConfiguration: .configuration(jettonInfo: item.jetton.jettonInfo, subtitle: amount),
        rightItemConfiguration: nil
      ),
      accessoryConfiguration: .none
    )
    
    return TKUIListItemCell.Configuration(
      id: "",
      listItemConfiguration: listItemConfiguration,
      isHighlightable: false,
      selectionClosure: nil
    )
  }
  
  func mapStakingItem(_ item: BalanceStakingItemModel) -> TKUIListItemCell.Configuration {
    let amount = amountFormatter.formatAmount(
      BigUInt(item.info.amount),
      fractionDigits: TonInfo.fractionDigits,
      maximumFractionDigits: 2,
      symbol: TonInfo.symbol
    ).withTextStyle(.body2, color: .Text.secondary, alignment: .left, lineBreakMode: .byTruncatingTail)
    
    let listItemConfiguration = TKUIListItemView.Configuration(
      iconConfiguration: .configuration(poolInfo: item.poolInfo, imageLoader: imageLoader),
      contentConfiguration: TKUIListItemContentView.Configuration(
        leftItemConfiguration: .configuration(poolInfo: item.poolInfo, subtitle: amount),
        rightItemConfiguration: nil
      ),
      accessoryConfiguration: .none
    )
    
    return TKUIListItemCell.Configuration(
      id: "",
      listItemConfiguration: listItemConfiguration,
      isHighlightable: false,
      selectionClosure: nil
    )
  }
}

private extension TKUIListItemAccessoryView.Configuration {
  static var chevron: TKUIListItemAccessoryView.Configuration {
    .image(
      TKUIListItemImageAccessoryView.Configuration(
        image: .TKUIKit.Icons.Size16.chevronRight,
        tintColor: .Text.tertiary,
        padding: .zero
      )
    )
  }
}
