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
        title: TonInfo.name,
        isVerified: true,
        image: .ton,
        tokenAmount: "0",
        convertedAmount: "0",
        buttons: [.send(.ton), .receive(.ton), .buySell]
      )
    }
    let amount = mapper.mapTonBalance(tonBalance: balance.tonBalance, currency: balance.currency)
    return TokenDetailsModel(
      title: TonInfo.name,
      isVerified: true,
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
    let isVerified: Bool
    switch jettonItem.jettonInfo.verification {
    case .whitelist:
      isVerified = true
    case .none, .blacklist:
      isVerified = false
    }
    
    guard let balance else {
      return TokenDetailsModel(
        title: jettonItem.jettonInfo.name,
        isVerified: isVerified,
        image: .url(jettonItem.jettonInfo.imageURL),
        tokenAmount: "0",
        convertedAmount: "0",
        buttons: [.send(.jetton(jettonItem), enabled: false),
                  .receive(.jetton(jettonItem))]
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
      title: jettonItem.jettonInfo.name,
      isVerified: isVerified,
      image: .url(jettonItem.jettonInfo.imageURL),
      tokenAmount: tokenAmount,
      convertedAmount: convertedAmount,
      buttons: [.send(.jetton(jettonItem), enabled: jettonItem.jettonInfo.isTransferable),
                      .receive(.jetton(jettonItem))]
    )
  }
}
