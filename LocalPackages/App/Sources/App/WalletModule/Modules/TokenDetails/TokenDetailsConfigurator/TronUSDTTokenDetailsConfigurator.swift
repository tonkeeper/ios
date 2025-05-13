import UIKit
import TKUIKit
import KeeperCore
import TronSwift

struct TronUSDTTokenDetailsConfigurator: TokenDetailsConfigurator {
  
  var didTapChargeBattery: (() -> Void)?
  
  private let wallet: Wallet
  private let mapper: TokenDetailsMapper
  private let batteryCalculation: BatteryCalculation
  
  init(wallet: Wallet,
       mapper: TokenDetailsMapper,
       batteryCalculation: BatteryCalculation) {
    self.wallet = wallet
    self.mapper = mapper
    self.batteryCalculation = batteryCalculation
  }
  
  func getTokenModel(balance: ConvertedBalance?, isSecureMode: Bool) -> TokenDetailsModel {
    let usdtBalance = balance?.tronUSDT
    let amount = usdtBalance?.amount ?? 0
    
    let buttons = [
      TokenDetailsModel.Button(
        iconButton: .send(.usdtTron),
        isEnable: wallet.isSendAvailable && amount > 0
      ),
      TokenDetailsModel.Button(
        iconButton: .receive(.usdtTron),
        isEnable: true
      ),
      TokenDetailsModel.Button(
        iconButton: .swap(.usdtTron),
        isEnable: true
      )
    ]
    
    let tokenAmount: String
    let convertedAmount: String?
    if isSecureMode {
      tokenAmount = .secureModeValueShort
      convertedAmount = .secureModeValueShort
    } else {
      let amount = mapper.mapBalance(
        amount: amount,
        converted: usdtBalance?.converted ?? 0,
        fractionDigits: TronSwift.USDT.fractionDigits,
        symbol: TronSwift.USDT.symbol,
        currency: balance?.currency ?? .USD)
      tokenAmount = amount.tokenAmount
      convertedAmount = amount.convertedAmount
    }
    
    var bannerItems = [TokenDetailsBannerItem]()
    var batteryCharges = 0
    if let batteryBalance = balance?.batteryBalance, !batteryBalance.isBalanceZero,
       let charges = batteryCalculation.calculateCharges(tonAmount: batteryBalance.balanceDecimalNumber) {
      batteryCharges = charges
    }
    if batteryCharges < 300 {
      bannerItems.append(TokenDetailsTRC20BatteryBannerView.Configuration(chargeButtonAction: {
        self.didTapChargeBattery?()
      }))
    }
  
    return TokenDetailsModel(
      title: "Tether USD",
      caption: TokenDetailsModel.Caption(
        text: TronSwift.USDT.tag.withTextStyle(.body2, color: .Text.secondary, alignment: .center),
        action: nil
      ),
      image: .image(.App.Currency.Size96.usdt),
      network: .trc20,
      tokenAmount: tokenAmount,
      convertedAmount: convertedAmount,
      buttons: buttons,
      bannerItems: bannerItems
    )
  }
  
  func getDetailsURL() -> URL? {
    let string = "\(String.tronscan)/\(TronSwift.USDT.address.base58)"
    guard let url = URL(string: string) else { return nil }
    return url
  }
}
