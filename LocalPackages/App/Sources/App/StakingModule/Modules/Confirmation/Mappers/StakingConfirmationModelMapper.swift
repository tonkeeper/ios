import UIKit
import Foundation
import TKUIKit
import TKCore
import BigInt
import TonSwift
import KeeperCore

struct StakingConfirmationModelMapper {
  func map(
    model: StakingConfirmationModel,
    tapAction: ((@escaping (_ isActivity: Bool) -> Void, @escaping (_ isSuccess: Bool) -> Void) -> Void)?,
    completionAction: ((Bool) -> Void)?
  ) -> TKModalCardViewController.Configuration {
    let header = mapHeader(model)
    let listItems = mapListItems(model)
    let content = TKModalCardViewController.Configuration.Content(items: [.list(listItems)])
    let actionBar = mapActionBar(tapAction: tapAction, completionAction: completionAction)
    
    return .init(
      header: header,
      content: content,
      actionBar: actionBar
    )
  }
}

// MARK: - Private methods

private extension StakingConfirmationModelMapper {
  func mapActionBar(
    tapAction: ((@escaping (_ isActivity: Bool) -> Void, @escaping (_ isSuccess: Bool) -> Void) -> Void)?,
    completionAction: ((Bool) -> Void)?
  ) -> TKModalCardViewController.Configuration.ActionBar {
    TKModalCardViewController.Configuration.ActionBar(
      items: [
        .button(
          TKModalCardViewController.Configuration.Button(
            title: .buttonTitle,
            size: .large,
            category: .primary,
            isEnabled: true,
            isActivity: false,
            tapAction: tapAction,
            completionAction: { isSuccess in
              guard isSuccess else { return }
              completionAction?(isSuccess)
            }
          ),
          bottomSpacing: 0
        )
      ]
    )
  }
  
  func mapListItems(_ model: StakingConfirmationModel) -> [TKModalCardViewController.Configuration.ListItem] {
    var items = [TKModalCardViewController.Configuration.ListItem]()
    items.append(
      TKModalCardViewController.Configuration.ListItem(
        left: .wallet,
        rightTop: .value(model.wallet, numberOfLines: 0, isFullString: false),
        rightBottom: .value(nil, numberOfLines: 0, isFullString: false)
      )
    )
    
    items.append(
      TKModalCardViewController.Configuration.ListItem(
        left: .recipientTitle,
        rightTop: .value(model.provider, numberOfLines: 0, isFullString: true),
        rightBottom: .value(nil, numberOfLines: 0, isFullString: false)
      )
    )
    
    items.append(
      TKModalCardViewController.Configuration.ListItem(
        left: .recipientTitle,
        rightTop: .value(model.apyPercent, numberOfLines: 0, isFullString: true),
        rightBottom: .value(nil, numberOfLines: 0, isFullString: false)
      )
    )
    
    if let amount = model.amount {
      let rightBottom: TKModalCardViewController.Configuration.ListItem.RightItem<String?>
      switch model.amountConverted {
      case .loading:
        rightBottom = .loading
      case .value(let value):
        rightBottom = .value(value, numberOfLines: 1, isFullString: false)
      }
      items.append(
        TKModalCardViewController.Configuration.ListItem(
          left: .amountTitle,
          rightTop: .value(amount, numberOfLines: 0, isFullString: false),
          rightBottom: rightBottom
        )
      )
    }
    
    let feeTop: TKModalCardViewController.Configuration.ListItem.RightItem<String>
    switch model.fee {
    case .loading:
      feeTop = .loading
    case .value(let value):
      feeTop = .value(value, numberOfLines: 1, isFullString: false)
    }
    let feeBottom: TKModalCardViewController.Configuration.ListItem.RightItem<String?>
    switch model.feeConverted {
    case .loading:
      feeBottom = .loading
    case .value(let value):
      feeBottom = .value(value, numberOfLines: 1, isFullString: false)
    }
    
    items.append(
      TKModalCardViewController.Configuration.ListItem(
        left: .feeTitle,
        rightTop: feeTop,
        rightBottom: feeBottom
      )
    )
  
    return items
  }
  
  func mapHeader(_ model: StakingConfirmationModel) -> TKModalCardViewController.Configuration.Header {
    let headerView = HistoreEventDetailsTokenHeaderImageView()
    headerView.imageLoader = ImageLoader()
    headerView.configure(model: HistoreEventDetailsTokenHeaderImageView.Model(image: .url(model.providerImage)))
    
    let title = model.amount ?? ""
    let description = String.description
    
    let headerItem: TKModalCardViewController.Configuration.Item = .customView(headerView, bottomSpacing: 20)
    let descriptionItem: TKModalCardViewController.Configuration.Item = .text(
      TKModalCardViewController.Configuration.Text(
        text: description.withTextStyle(.body1, color: .Text.secondary, alignment: .center),
        numberOfLines: 1
      ),
      bottomSpacing: 4
    )
    let titleItem: TKModalCardViewController.Configuration.Item = .text(
      TKModalCardViewController.Configuration.Text(
        text: title.withTextStyle(.h3, color: .Text.primary, alignment: .center),
        numberOfLines: 1
      ),
      bottomSpacing: 0
    )
    
    return .init(items: [headerItem, descriptionItem, titleItem])
  }
}

private extension String {
  static let wallet = "Wallet"
  static let description = "Deposit"
  static let recipientTitle = "Recipient"
  static let recipientAddressTitle = "Recipient address"
  static let amountTitle = "Amount"
  static let feeTitle = "Fee"
  static let buttonTitle = "Stake"
}

private extension CGFloat {
  static let imageHeight: CGFloat = 96
}
