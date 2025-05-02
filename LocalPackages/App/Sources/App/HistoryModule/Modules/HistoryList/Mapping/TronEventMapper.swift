import UIKit
import TKLocalize
import TKUIKit
import KeeperCore
import TronSwift
import BigInt

struct TronEventMapper {
  
  private let dateFormatter: DateFormatter
  private let amountFormatter: AmountFormatter
  private let amountMapper: AccountEventAmountMapper
  
  init(dateFormatter: DateFormatter,
       amountFormatter: AmountFormatter,
       amountMapper: AccountEventAmountMapper) {
    self.dateFormatter = dateFormatter
    self.amountFormatter = amountFormatter
    self.amountMapper = amountMapper
  }
  
  func mapEvent(_ event: TronTransaction,
                owner: TronSwift.Address,
                dateFormat: String,
                tapAction: @escaping () -> Void) -> HistoryCell.Model {
    let eventType = event.getTransactionType(address: owner)
    let icon: UIImage
    switch eventType {
    case .send:
      icon = .App.Icons.Size28.trayArrowUp
    case .receive:
      icon = .App.Icons.Size28.trayArrowDown
    }
    let imageModel = TKUIListItemImageIconView.Configuration(
      image: .image(icon),
      tintColor: .Icon.secondary,
      backgroundColor: .Background.contentTint,
      size: CGSize(width: 44, height: 44),
      cornerRadius: 22
    )
    let iconConfiguration = HistoryCellIconView.Configuration(
      imageModel: imageModel
    )
    
    let title: NSAttributedString = {
      let title: String
      switch eventType {
      case .send:
        title = TKLocales.ActionTypes.sent
      case .receive:
        title = TKLocales.ActionTypes.received
      }
      return title.withTextStyle(
        .label1,
        color: .Text.primary,
        alignment: .left,
        lineBreakMode: .byTruncatingTail
      )
    }()
    
    let subtitle: NSAttributedString = {
      let subtitle: String
      switch eventType {
      case .send:
        subtitle = event.toAccount.shortBase58
      case .receive:
        subtitle = event.fromAccount.shortBase58
      }
      return subtitle.withTextStyle(
        .body2,
        color: .Text.secondary,
        alignment: .left,
        lineBreakMode: .byTruncatingTail
      )
    }()
    
    dateFormatter.dateFormat = dateFormat
    let date = dateFormatter
      .string(from: Date(timeIntervalSince1970: TimeInterval(event.timestamp)))
      .withTextStyle(
        .body2,
        color: .Text.secondary,
        alignment: .right,
        lineBreakMode: .byWordWrapping
    )
    
    let status: NSAttributedString? = {
      guard event.isFailed else { return nil }
      return "Failed".withTextStyle(
        .body2,
        color: .Accent.orange,
        alignment: .left,
        lineBreakMode: .byTruncatingTail
      )
    }()
    
    let value: NSAttributedString = {
      let amountType: AccountEventActionAmountMapperActionType
      let color: UIColor
      switch eventType {
      case .send:
        amountType = .outcome
        color = .Text.primary
      case .receive:
        amountType = .income
        color = .Accent.green
      }
      let amount = amountMapper
        .mapAmount(
          amount: event.amount,
          fractionDigits: TronSwift.USDT.fractionDigits,
          maximumFractionDigits: TronSwift.USDT.fractionDigits,
          type: amountType,
          symbol: TronSwift.USDT.symbol)
      return amount.withTextStyle(
        .label1,
        color: color,
        alignment: .right,
        lineBreakMode: .byTruncatingTail
      )
    }()
    
    let tagViewModel = TKUITagView.Configuration(
      text: TronSwift.USDT.tag,
      textColor: .Text.secondary,
      backgroundColor: .Background.contentTint
    )
    
    let leftItemConfiguration = TKUIListItemContentLeftItem.Configuration(
      title: title,
      tagViewModel: tagViewModel,
      subtitle: subtitle,
      description: status,
      descriptionNumberOfLines: 1
    )
    let rightItemConfiguration = TKUIListItemContentRightItem.Configuration(
      value: value,
      valueNumberOfLines: 0,
      subtitle: date,
      description: nil
    )
    
    let contentConfiguration = TKUIListItemContentView.Configuration(
      leftItemConfiguration: leftItemConfiguration,
      rightItemConfiguration: rightItemConfiguration,
      isVerticalCenter: false
    )
    
    let action = HistoryCellContentView.Model.Action(
      configuration: HistoryCellActionView.Model(
        iconConfiguration: iconConfiguration,
        contentConfiguration: contentConfiguration,
        isInProgress: event.isPending
      ),
      action: {
        tapAction()
      }
    )
    
    return HistoryCell.Model(
      id: event.txID,
      historyContentConfiguration: HistoryCellContentView.Model(
        actions: [action]
      )
    )
  }
}
