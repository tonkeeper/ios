import UIKit
import Foundation
import TKUIKit
import TKCore
import BigInt
import TonSwift
import KeeperCore
import SnapKit

struct StakingConfirmationModelMapper {
  func map(
    model: StakingConfirmationModel,
    tapAction: ((@escaping (_ isActivity: Bool) -> Void, @escaping (_ isSuccess: Bool) -> Void) -> Void)?,
    completionAction: ((Bool) -> Void)?
  ) -> TKModalCardViewController.Configuration {
    let header = mapHeader(model)
    let listItems = mapListItems(model)
    let content = TKModalCardViewController.Configuration.Content(items: [.list(listItems)])
    
    return .init(
      header: header,
      content: content
    )
  }
}

// MARK: - Private methods

private extension StakingConfirmationModelMapper {  
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
        rightTop: .value(model.poolName, numberOfLines: 0, isFullString: true),
        rightBottom: .value(nil, numberOfLines: 0, isFullString: false)
      )
    )
    
    if let apyPercent = model.apyPercent {
      items.append(
        TKModalCardViewController.Configuration.ListItem(
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
      TKModalCardViewController.Configuration.ListItem(
        left: .feeTitle,
        rightTop: feeTop,
        rightBottom: feeBottom
      )
    )
    
    return items
  }
  
  func mapHeader(_ model: StakingConfirmationModel) -> TKModalCardViewController.Configuration.Header {
    var items: [TKModalCardViewController.Configuration.Item] = []
    
    let headerView = StakingConfirmationHeaderView()
    headerView.imageLoader = ImageLoader()
    let image: Image
    switch model.poolImage {
    case .fromResource:
      image = .image(model.kind.image, tinColor: nil, backgroundColor: nil)
    case .url(let url):
      image = .url(url)
    }
    headerView.configure(model: StakingConfirmationHeaderView.Model(image: image))
    let headerItem: TKModalCardViewController.Configuration.Item = .customView(headerView, bottomSpacing: 20)
    items.append(headerItem)
    
    let hintItem: TKModalCardViewController.Configuration.Item = .text(
      .init(text: model.operationName.withTextStyle(.body1, color: .Text.secondary, alignment: .center), numberOfLines: 1),
      bottomSpacing: 4
    )
    items.append(hintItem)
    
    let title = model.amount + " \(model.tokenSymbol)"
    let titleItem: TKModalCardViewController.Configuration.Item = .text(
      .init(text: title.withTextStyle(.h3, color: .Text.primary, alignment: .center), numberOfLines: 1),
      bottomSpacing: 0
    )
    items.append(titleItem)
    
    if let convertedAmount = model.amountConverted {
      let subtitleItem: TKModalCardViewController.Configuration.Item = .text(
        .init(text: convertedAmount.withTextStyle(.body1, color: .Text.secondary, alignment: .center), numberOfLines: 1),
        bottomSpacing: 0
      )
      items.append(subtitleItem)
      
    }
    
    return .init(items: items)
  }
}

private extension String {
  static let wallet = "Wallet"
  static let recipientTitle = "Recipient"
  static let apyTitle = "APY"
  static let feeTitle = "Fee"
  static let buttonTitle = "Stake"
}

private extension CGFloat {
  static let imageHeight: CGFloat = 96
}
