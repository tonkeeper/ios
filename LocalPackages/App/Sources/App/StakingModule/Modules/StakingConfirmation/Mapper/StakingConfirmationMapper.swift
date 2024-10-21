import UIKit
import Foundation
import TKUIKit
import TKCore
import BigInt
import TonSwift
import KeeperCore
import SnapKit
import TKLocalize

struct StakingConfirmationMapper {
  func map(
    model: StakeConfirmationModel,
    tapAction: ((@escaping (_ isActivity: Bool) -> Void, @escaping (_ isSuccess: Bool) -> Void) -> Void)?,
    completionAction: ((Bool) -> Void)?
  ) -> TKModalCardViewController.Configuration {
    let header = mapHeader(model)
    let listItems = mapListItems(model)
    let content = TKModalCardViewController.Configuration.Content(items: [.list(listItems)], copyToastConfiguration: .copied)
    
    let actionBar = TKModalCardViewController.Configuration.ActionBar(
      items: [
        .button(
          TKModalCardViewController.Configuration.Button(
            title: model.buttonTitle,
            size: .large,
            category: .primary,
            isEnabled: true,
            isActivity: false,
            tapAction: tapAction,
            completionAction: completionAction
          ),
          bottomSpacing: 0
        )
      ]
    )
    
    return TKModalCardViewController.Configuration(
      header: header,
      content: content,
      actionBar: actionBar
    )
  }
}

// MARK: - Private methods

private extension StakingConfirmationMapper {
  func mapListItems(_ model: StakeConfirmationModel) -> [TKModalCardViewController.Configuration.ListItem] {
    var items = [TKModalCardViewController.Configuration.ListItem]()
    
    let senderWalletName = model.wallet.iconWithName(
      attributes: TKTextStyle.label1.getAttributes(color: .Text.primary, alignment: .right, lineBreakMode: .byTruncatingTail),
      iconColor: .Icon.primary,
      iconSide: 20
    )
    items.append(
      TKModalCardViewController.Configuration.ListItem(
        left: .wallet,
        rightTop: .value(senderWalletName, numberOfLines: 0, isFullString: false),
        rightBottom: .value(nil, numberOfLines: 0, isFullString: false)
      )
    )
    
    items.append(
      TKModalCardViewController.Configuration.ListItem.defaultItem(
        left: .recipientTitle,
        rightTop: .value(model.poolName, numberOfLines: 0, isFullString: true),
        rightBottom: .value(nil, numberOfLines: 0, isFullString: false)
      )
    )
    
    let amount = model.amount + " \(model.tokenSymbol)"
    items.append(
      TKModalCardViewController.Configuration.ListItem.defaultItem(
        left: .amountTitle,
        rightTop: .value(amount, numberOfLines: 0, isFullString: true),
        rightBottom: .value(model.amountConverted, numberOfLines: 0, isFullString: false)
      )
    )
    
    if let apyPercent = model.apyPercent {
      items.append(
        TKModalCardViewController.Configuration.ListItem.defaultItem(
          left: .apyTitle,
          rightTop: .value(apyPercent, numberOfLines: 0, isFullString: true),
          rightBottom: .value(nil, numberOfLines: 0, isFullString: false)
        )
      )
    }
    
    let feeTop: TKModalCardViewController.Configuration.ListItem.RightItem<String>
    switch model.fee {
    case .loading:
      feeTop = .loading
    case .value(let value):
      feeTop = .value("≈ \(value)", numberOfLines: 1, isFullString: false)
    }
    let feeBottom: TKModalCardViewController.Configuration.ListItem.RightItem<String?>
    switch model.feeConverted {
    case .loading:
      feeBottom = .loading
    case .value(let value):
      feeBottom = .value(value, numberOfLines: 1, isFullString: false)
    }
    
    items.append(
      TKModalCardViewController.Configuration.ListItem.defaultItem(
        left: .feeTitle,
        rightTop: feeTop,
        rightBottom: feeBottom
      )
    )
    
    return items
  }
  
  func mapHeader(_ model: StakeConfirmationModel) -> TKModalCardViewController.Configuration.Header {
    var items: [TKModalCardViewController.Configuration.Item] = []
    
    let headerView = HistoreEventDetailsTokenHeaderImageView()
    headerView.configure(
      model: HistoreEventDetailsTokenHeaderImageView.Model(
        image: .image(
          model.poolImplementation.icon,
          tinColor: nil,
          backgroundColor: nil
        )
      )
    )
    let headerItem: TKModalCardViewController.Configuration.Item = .customView(headerView, bottomSpacing: 20)
    items.append(headerItem)
    
    let hintItem: TKModalCardViewController.Configuration.Item = .text(
      .init(text: TKLocales.StakingConfirmationMapper.confirmAction.withTextStyle(.body1, color: .Text.secondary, alignment: .center), numberOfLines: 1),
      bottomSpacing: 4
    )
    items.append(hintItem)
    
    let title = model.operationName
    let titleItem: TKModalCardViewController.Configuration.Item = .text(
      .init(text: title.withTextStyle(.h3, color: .Text.primary, alignment: .center), numberOfLines: 1),
      bottomSpacing: 0
    )
    items.append(titleItem)
    
    return .init(items: items)
  }
}

private extension String {
  static let wallet = TKLocales.StakingConfirmationMapper.wallet
  static let recipientTitle = TKLocales.StakingConfirmationMapper.recipient
  static let amountTitle = TKLocales.StakingConfirmationMapper.amount
  static let apyTitle = TKLocales.StakingConfirmationMapper.apy
  static let feeTitle = TKLocales.StakingConfirmationMapper.fee
  static let buttonTitle = TKLocales.StakingConfirmationMapper.stake
}

private extension CGFloat {
  static let imageHeight: CGFloat = 96
}
