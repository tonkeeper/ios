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
    let tonAmount = balance?.tonBalance.tonBalance.amount ?? 0
    
    let buttons = [
      TokenDetailsModel.Button(
        iconButton: .send(.ton),
        isEnable: wallet.isSendAvailable && tonAmount > 0
      ),
      TokenDetailsModel.Button(
        iconButton: .receive(.ton),
        isEnable: true
      ),
      TokenDetailsModel.Button(
        iconButton: .swap(.ton),
        isEnable: wallet.isSwapEnable
      )
    ]
    
    let tokenAmount: String
    let convertedAmount: String?
    if isSecureMode {
      tokenAmount = .secureModeValueShort
      convertedAmount = .secureModeValueShort
    } else {
      let amount = mapper.mapTonBalance(tonBalance: balance?.tonBalance, currency: balance?.currency)
      tokenAmount = amount.tokenAmount
      convertedAmount = amount.convertedAmount
    }

    return TokenDetailsModel(
      title: TonInfo.name,
      isVerified: true,
      image: .ton,
      tokenAmount: tokenAmount,
      convertedAmount: convertedAmount,
      buttons: buttons
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
    
    let jettonBalance = balance?.jettonsBalance.first(where: { $0.jettonBalance.item.jettonInfo == jettonItem.jettonInfo })?.jettonBalance
    let jettonAmount = jettonBalance?.quantity ?? 0
    let currency = balance?.currency ?? .defaultCurrency
    
    let buttons = [
      TokenDetailsModel.Button(
        iconButton: .send(.jetton(jettonItem)),
        isEnable: wallet.isSendAvailable && jettonItem.jettonInfo.isTransferable && jettonAmount > 0
      ),
      TokenDetailsModel.Button(
        iconButton: .receive(.jetton(jettonItem)),
        isEnable: true
      ),
      TokenDetailsModel.Button(
        iconButton: .swap(.jetton(jettonItem)),
        isEnable: wallet.isSwapEnable
      )
    ]

    let tokenAmount: String
    var convertedAmount: String?
    if isSecureMode {
      tokenAmount = .secureModeValueShort
      convertedAmount = .secureModeValueShort
    } else {
      (tokenAmount, convertedAmount) = mapper.mapJettonBalance(jettonBalance: jettonBalance, currency: currency)
    }
    
    return TokenDetailsModel(
      title: jettonItem.jettonInfo.name,
      isVerified: isVerified,
      image: .url(jettonItem.jettonInfo.imageURL),
      tokenAmount: tokenAmount,
      convertedAmount: convertedAmount,
      buttons: buttons
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
