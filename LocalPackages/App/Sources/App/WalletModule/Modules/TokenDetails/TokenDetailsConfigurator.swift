import Foundation
import BigInt
import TKLocalize
import KeeperCore

protocol TokenDetailsConfigurator {
  func getTokenModel(balance: ConvertedBalance?) -> TokenDetailsModel
}

struct TonTokenDetailsConfigurator: TokenDetailsConfigurator {
  private let mapper: TokenDetailsMapper
  
  init(mapper: TokenDetailsMapper) {
    self.mapper = mapper
  }
  
  func getTokenModel(balance: ConvertedBalance?) -> TokenDetailsModel {
    guard let balance else {
      return TokenDetailsModel(
        tokenTitle: TonInfo.name,
        tokenSubtitle: nil,
        image: .ton,
        tokenAmount: "0",
        convertedAmount: "0",
        buttons: [.send(.ton), .receive(.ton), .buySell]
      )
    }
    let amount = mapper.mapTonBalance(tonBalance: balance.tonBalance, currency: balance.currency)
    return TokenDetailsModel(
      tokenTitle: TonInfo.name,
      tokenSubtitle: nil,
      image: .ton,
      tokenAmount: amount.tokenAmount,
      convertedAmount: amount.convertedAmount,
      buttons: [.send(.ton), .receive(.ton), .buySell]
    )
  }
}

struct JettonTokenDetailsConfigurator: TokenDetailsConfigurator {
  
  private let jettonItem: JettonItem
  private let mapper: TokenDetailsMapper
  
  init(jettonItem: JettonItem,
       mapper: TokenDetailsMapper) {
    self.jettonItem = jettonItem
    self.mapper = mapper
  }
  
  func getTokenModel(balance: ConvertedBalance?) -> TokenDetailsModel {
    let subtitle: String?
    switch jettonItem.jettonInfo.verification {
    case .whitelist:
      subtitle = nil
    case .none:
      subtitle = TKLocales.Token.unverified
    case .blacklist:
      subtitle = TKLocales.Token.unverified
    }
    
    guard let balance else {
      return TokenDetailsModel(
        tokenTitle: jettonItem.jettonInfo.name,
        tokenSubtitle: subtitle,
        image: .url(jettonItem.jettonInfo.imageURL),
        tokenAmount: "0",
        convertedAmount: "0",
        buttons: [.send(.jetton(jettonItem)), .receive(.jetton(jettonItem))]
      )
    }
    
    let tokenAmount: String
    var convertedAmount: String?
    if let jettonBalance = balance.jettonsBalance.first(where: { $0.jettonBalance.item.jettonInfo == jettonItem.jettonInfo }) {
      (tokenAmount, convertedAmount) = mapper.mapJettonBalance(jettonBalance: jettonBalance, currency: balance.currency)
    } else {
      tokenAmount = "0"
      convertedAmount = nil
    }
    return TokenDetailsModel(
      tokenTitle: jettonItem.jettonInfo.name,
      tokenSubtitle: subtitle,
      image: .url(jettonItem.jettonInfo.imageURL),
      tokenAmount: tokenAmount,
      convertedAmount: convertedAmount,
      buttons: [.send(.jetton(jettonItem)), .receive(.jetton(jettonItem))]
    )
  }
}
