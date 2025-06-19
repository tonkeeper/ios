import Foundation
import BigInt
import TKLocalize
import TKFeatureFlags
import KeeperCore

struct JettonTokenDetailsConfigurator: TokenDetailsConfigurator {
  
  private let wallet: Wallet
  private let jettonItem: JettonItem
  private let mapper: TokenDetailsMapper
  private let configuration: Configuration
  
  init(wallet: Wallet,
       jettonItem: JettonItem,
       mapper: TokenDetailsMapper,
       configuration: Configuration) {
    self.wallet = wallet
    self.jettonItem = jettonItem
    self.mapper = mapper
    self.configuration = configuration
  }
  
  func getTokenModel(balance: ConvertedBalance?, isSecureMode: Bool) -> TokenDetailsModel {
    let jettonBalance = balance?.jettonsBalance.first(where: { $0.jettonBalance.item.jettonInfo == jettonItem.jettonInfo })?.jettonBalance
    let jettonAmount = jettonBalance?.quantity ?? 0
    let currency = balance?.currency ?? .defaultCurrency
    
    var buttons = [
      TokenDetailsModel.Button(
        iconButton: .send(.ton(.jetton(jettonItem))),
        isEnable: wallet.isSendAvailable && jettonItem.jettonInfo.isTransferable && jettonAmount > 0
      ),
      TokenDetailsModel.Button(
        iconButton: .receive(.ton(.jetton(jettonItem))),
        isEnable: true
      )
    ]
    
    if !TKFeatureFlags.provider.isSwapDisable {
      buttons.append(
        TokenDetailsModel.Button(
          iconButton: .swap(.ton(.jetton(jettonItem))),
          isEnable: wallet.isSwapEnable
      ))
    }
    
    let tokenAmount: String
    var convertedAmount: String?
    if isSecureMode {
      tokenAmount = .secureModeValueShort
      convertedAmount = .secureModeValueShort
    } else {
      (tokenAmount, convertedAmount) = mapper.mapJettonBalance(jettonBalance: jettonBalance, currency: currency)
    }
    
    var caption: TokenDetailsModel.Caption?
    if jettonItem.jettonInfo.verification != .whitelist {
      caption = TokenDetailsModel.Caption(
        text: TKLocales.Token.unverified.withTextStyle(.body2, color: .Accent.orange),
        icon: .TKUIKit.Icons.Size12.informationCircle
      )
    } else if jettonItem.jettonInfo.isTonUSDT && wallet.isTronTurnOn {
      caption = TokenDetailsModel.Caption(
        text: "TON".withTextStyle(.body2, color: .Text.secondary, alignment: .center)
      )
    }
    
    return TokenDetailsModel(
      title: jettonItem.jettonInfo.name,
      caption: caption,
      image: .urlImage(jettonItem.jettonInfo.imageURL),
      network: wallet.isTronTurnOn && jettonItem.jettonInfo.isTonUSDT ? .ton : .none,
      tokenAmount: tokenAmount,
      convertedAmount: convertedAmount,
      buttons: buttons,
      bannerItems: []
    )
  }
  
  func getDetailsURL() -> URL? {
    guard let string = try? "\(String.tonviewer)/\(wallet.friendlyAddress.toString())/jetton/\(jettonItem.jettonInfo.address.toString())",
          let url = URL(string: string) else { return nil }
    return url
  }
}
