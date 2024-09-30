import Foundation
import BigInt
import TKLocalize
import KeeperCore

protocol TokenDetailsConfigurator {
  func getTokenModel(balance: ConvertedBalance?, isSecureMode: Bool) -> TokenDetailsModel
  func getDetailsURL() -> URL?
}

struct TonTokenDetailsConfigurator: TokenDetailsConfigurator {
  private let wallet: Wallet
  private let mapper: TokenDetailsMapper
  
  init(wallet: Wallet,
       mapper: TokenDetailsMapper) {
    self.wallet = wallet
    self.mapper = mapper
  }
  
  func getTokenModel(balance: ConvertedBalance?, isSecureMode: Bool) -> TokenDetailsModel {
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
    
    let tokenAmount: String
    let convertedAmount: String?
    if isSecureMode {
      tokenAmount = .secureModeValue
      convertedAmount = .secureModeValue
    } else {
      let amount = mapper.mapTonBalance(tonBalance: balance.tonBalance, currency: balance.currency)
      tokenAmount = amount.tokenAmount
      convertedAmount = amount.convertedAmount
    }

    return TokenDetailsModel(
      title: TonInfo.name,
      isVerified: true,
      image: .ton,
      tokenAmount: tokenAmount,
      convertedAmount: convertedAmount,
      buttons: [.send(.ton), .receive(.ton), .buySell]
    )
  }
  
  func getDetailsURL() -> URL? {
    guard let string = try? "\(String.tonviewer)/\(wallet.friendlyAddress.toString())",
          let url = URL(string: string) else { return nil }
    return url
  }
}

struct JettonTokenDetailsConfigurator: TokenDetailsConfigurator {
  
  private let wallet: Wallet
  private let jettonItem: JettonItem
  private let mapper: TokenDetailsMapper
  
  init(wallet: Wallet, 
       jettonItem: JettonItem,
       mapper: TokenDetailsMapper) {
    self.wallet = wallet
    self.jettonItem = jettonItem
    self.mapper = mapper
  }
  
  func getTokenModel(balance: ConvertedBalance?, isSecureMode: Bool) -> TokenDetailsModel {
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
        tokenAmount: isSecureMode ? .secureModeValue : "0",
        convertedAmount: isSecureMode ? .secureModeValue : "0",
        buttons: [.send(.jetton(jettonItem), enabled: false),
                  .receive(.jetton(jettonItem))]
      )
    }
    
    let tokenAmount: String
    var convertedAmount: String?
    if isSecureMode {
      tokenAmount = .secureModeValue
      convertedAmount = .secureModeValue
    } else if let jettonBalance = balance.jettonsBalance.first(where: { $0.jettonBalance.item.jettonInfo == jettonItem.jettonInfo }) {
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
  
  func getDetailsURL() -> URL? {
    guard let string = try? "\(String.tonviewer)/\(wallet.friendlyAddress.toString())/jetton/\(jettonItem.jettonInfo.address.toString())",
          let url = URL(string: string) else { return nil }
    return url
  }
}

private extension String {
  static let tonviewer = "https://tonviewer.com"
}
