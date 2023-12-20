//
//  WalletBalanceModelMapper.swift
//  Tonkeeper
//
//  Created by Grigory on 2.7.23..
//

import UIKit
import WalletCoreKeeper

final class WalletBalanceModelMapper {
  func map(pages: [WalletBalanceModel.Page]) -> [WalletContentPage] {
    return pages.map { page in
      let sections = page.sections.map { map(section: $0) }
      return WalletContentPage(title: page.title, sections: sections)
    }
  }
}

private extension WalletBalanceModelMapper {
  func map(section: WalletBalanceModel.Section) -> TokensListSection {
    switch section {
    case let .token(items):
      let cellModels = items.map { map(item: $0) }
      return .init(type: .token, items: cellModels)
    case let .collectibles(collectibles):
      let cellModels = collectibles.map { map(collectible: $0) }
      return .init(type: .collectibles, items: cellModels)
    }
  }
  
  func map(item: WalletItemViewModel) -> TokenListTokenCell.Model {
    let image: Image = .with(image: item.image)
    
    var priceDiff: NSAttributedString?
    if let leftRightSubtitle = item.leftRightSubtitle {
      let color: UIColor
      if leftRightSubtitle.hasPrefix("-") {
        color = .Accent.red
      } else {
        color = .Accent.green
      }
      priceDiff = leftRightSubtitle.attributed(with: .body2, alignment: .left, color: color)
    }
    
    return .init(image: image,
                 title: item.leftTitle,
                 shortTitle: item.rightTitle,
                 price: item.leftLeftSubtitle,
                 priceDiff: priceDiff,
                 amount: item.rightValue,
                 fiatAmount: item.rightSubvalue)
  }
  
  func map(collectible: WalletCollectibleItemViewModel) -> TokensListCollectibleCell.Model {
    .init(image: .url(collectible.imageURL),
          title: collectible.title,
          subtitle: collectible.subtitle)
  }
}

extension Image {
  static func with(image: WalletCoreKeeper.Image) -> Image {
    switch image {
    case .ton: return .image(.Icons.tonIcon, tinColor: .Icon.primary, backgroundColor: .Constant.tonBlue)
    case .oldWallet: return .image(.Icons.tonIcon, tinColor: .Icon.primary, backgroundColor: .Button.tertiaryBackground)
    case let .url(url): return .url(url)
    }
  }
}
