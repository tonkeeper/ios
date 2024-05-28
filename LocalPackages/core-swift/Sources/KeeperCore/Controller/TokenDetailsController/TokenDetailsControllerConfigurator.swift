import Foundation
import BigInt
import TKLocalize

protocol TokenDetailsControllerConfigurator {
  func getTokenModel(balance: Balance, tonRates: [Rates.Rate], currency: Currency) -> TokenDetailsController.TokenModel
}

struct TonTokenDetailsControllerConfigurator: TokenDetailsControllerConfigurator {
  private let mapper: TokenDetailsMapper
  
  init(mapper: TokenDetailsMapper) {
    self.mapper = mapper
  }
  
  func getTokenModel(balance: Balance, tonRates: [Rates.Rate], currency: Currency) -> TokenDetailsController.TokenModel {
    let amount = mapper.mapTonBalance(
      amount: balance.tonBalance.amount,
      tonRates: tonRates,
      currency: currency
    )
    return TokenDetailsController.TokenModel(
      tokenTitle: TonInfo.name,
      tokenSubtitle: nil,
      image: .ton,
      tokenAmount: amount.tokenAmount,
      convertedAmount: amount.convertedAmount,
      buttons: [.send(.ton), .receive(.ton), .buySell]
    )
  }
}

struct JettonTokenDetailsControllerConfigurator: TokenDetailsControllerConfigurator {
  
  private let jettonItem: JettonItem
  private let mapper: TokenDetailsMapper
  
  init(jettonItem: JettonItem,
       mapper: TokenDetailsMapper) {
    self.jettonItem = jettonItem
    self.mapper = mapper
  }
  
  func getTokenModel(balance: Balance, tonRates: [Rates.Rate], currency: Currency) -> TokenDetailsController.TokenModel {
    let subtitle: String?
    switch jettonItem.jettonInfo.verification {
    case .whitelist:
      subtitle = nil
    case .none:
      subtitle = TKLocales.Token.unverified
    case .blacklist:
      subtitle = TKLocales.Token.unverified
    }
    
    let tokenAmount: String
    var convertedAmount: String?
    if let jettonBalance = balance.jettonsBalance.first(where: { $0.item.jettonInfo == jettonItem.jettonInfo }) {
     (tokenAmount, convertedAmount) = mapper.mapJettonBalance(jettonBalance: jettonBalance, currency: currency)
    } else {
      tokenAmount = "0"
      convertedAmount = nil
    }
    return TokenDetailsController.TokenModel(
      tokenTitle: jettonItem.jettonInfo.name,
      tokenSubtitle: subtitle,
      image: .url(jettonItem.jettonInfo.imageURL),
      tokenAmount: tokenAmount,
      convertedAmount: convertedAmount,
      buttons: [.send(.jetton(jettonItem)), .receive(.jetton(jettonItem))]
    )
  }
}


struct LPJettonDetailsControllerConfigurator: TokenDetailsControllerConfigurator {
  private let jettonItem: JettonItem
  private let mapper: TokenDetailsMapper
  private let stakingPool: StakingPool
  
  init(jettonItem: JettonItem, mapper: TokenDetailsMapper, stakingPool: StakingPool) {
    self.jettonItem = jettonItem
    self.mapper = mapper
    self.stakingPool = stakingPool
  }
  
  func getTokenModel(balance: Balance, tonRates: [Rates.Rate], currency: Currency) -> TokenDetailsController.TokenModel {
    let subtitle: String?
    switch jettonItem.jettonInfo.verification {
    case .whitelist:
      subtitle = nil
    case .none:
      subtitle = TKLocales.Token.unverified
    case .blacklist:
      subtitle = TKLocales.Token.unverified
    }
    
    let tokenAmount: String
    var convertedAmount: String?
    if let jettonBalance = balance.jettonsBalance.first(where: { $0.item.jettonInfo == jettonItem.jettonInfo }) {
     (tokenAmount, convertedAmount) = mapper.mapJettonBalance(jettonBalance: jettonBalance, currency: currency)
    } else {
      tokenAmount = "0"
      convertedAmount = nil
    }
    return TokenDetailsController.TokenModel(
      tokenTitle: jettonItem.jettonInfo.name,
      tokenSubtitle: subtitle,
      image: .url(jettonItem.jettonInfo.imageURL),
      tokenAmount: tokenAmount,
      convertedAmount: convertedAmount,
      buttons: [.deposit(jettonItem, stakingPool), .withdraw(jettonItem, stakingPool)]
    )
  }
}
