import Foundation
import BigInt

struct SwapTokenListMapper {
  
  private let amountFormatter: AmountFormatter
  private let rateConverter: RateConverter
  
  init(amountFormatter: AmountFormatter, rateConverter: RateConverter) {
    self.amountFormatter = amountFormatter
    self.rateConverter = rateConverter
  }
  
  func mapStonfiAsset(_ asset: StonfiAsset) -> SwapTokenListItemsModel.Item {
    var imageUrl: URL?
    if let imageUrlString = asset.imageUrl  {
      imageUrl = URL(string: imageUrlString)
    }
    
    let assetKind = AssetKind(fromString: asset.kind)
    
    let displayName: String
    if assetKind == .ton, asset.displayName == TonInfo.symbol {
      displayName = TonInfo.name
    } else {
      displayName = asset.displayName ?? ""
    }
    
    var badge: String?
    if assetKind == .ton && asset.symbol != TonInfo.symbol {
      badge = asset.kind
    }
    
    let swapAsset = SwapAsset(
      contractAddress: asset.contractAddress,
      kind: assetKind,
      symbol: asset.symbol,
      displayName: displayName,
      fractionDigits: asset.decimals,
      imageUrl: imageUrl
    )
    
    return SwapTokenListItemsModel.Item(
      asset: swapAsset,
      image: .asyncImage(imageUrl),
      badge: badge,
      amount: nil,
      convertedAmount: nil
    )
  }
  
  func mapBalance(balance: Balance,
                  rates: Rates,
                  currency: Currency) -> [AssetKind : [AssetBalance]] {
    let tonItem = mapTon(
      tonBalance: balance.tonBalance,
      tonRates: rates.ton,
      currency: currency
    )
    
    let jettonItems = mapJettons(
      jettonsBalance: balance.jettonsBalance,
      jettonsRates: rates.jettonsRates,
      currency: currency
    )
    
    return [
      .ton : [tonItem],
      .jetton : jettonItems
    ]
  }
  
  func mapTon(tonBalance: TonBalance,
              tonRates: [Rates.Rate],
              currency: Currency) -> AssetBalance {
    let bigUIntAmount = BigUInt(tonBalance.amount)
    let amount = amountFormatter.formatAmount(
      bigUIntAmount,
      fractionDigits: TonInfo.fractionDigits,
      maximumFractionDigits: 2
    )
    var convertedAmount: String?
    
    if let rate = tonRates.first(where: { $0.currency == currency }) {
      let converted = rateConverter.convert(
        amount: bigUIntAmount,
        amountFractionLength: TonInfo.fractionDigits,
        rate: rate
      )
      convertedAmount = amountFormatter.formatAmount(
        converted.amount,
        fractionDigits: converted.fractionLength,
        maximumFractionDigits: 2,
        currency: currency
      )
    }
    
    return AssetBalance(
      assetSymbol: TonInfo.symbol,
      amount: amount,
      convertedAmount: convertedAmount
    )
  }
  
  func mapJettons(jettonsBalance: [JettonBalance],
                  jettonsRates: [Rates.JettonRate],
                  currency: Currency) -> [AssetBalance] {
    var unverified = [JettonBalance]()
    var verified = [JettonBalance]()
    for jettonBalance in jettonsBalance {
      switch jettonBalance.item.jettonInfo.verification {
      case .whitelist:
        verified.append(jettonBalance)
      default:
        unverified.append(jettonBalance)
      }
    }
    
    return (verified + unverified)
      .compactMap { jettonBalance in
        guard !jettonBalance.quantity.isZero else { return nil }
        let jettonRates = jettonsRates.first(where: { $0.jettonInfo == jettonBalance.item.jettonInfo })
        return mapJetton(
          jettonBalance: jettonBalance,
          jettonRates: jettonRates,
          currency: currency
        )
      }
  }
  
  func mapJetton(jettonBalance: JettonBalance,
                 jettonRates: Rates.JettonRate?,
                 currency: Currency) -> AssetBalance {
    let amount = amountFormatter.formatAmount(
      jettonBalance.quantity,
      fractionDigits: jettonBalance.item.jettonInfo.fractionDigits,
      maximumFractionDigits: 2
    )
    
    var convertedAmount: String?
    if let rate = jettonBalance.rates[currency] {
      let converted = rateConverter.convert(
        amount: jettonBalance.quantity,
        amountFractionLength: jettonBalance.item.jettonInfo.fractionDigits,
        rate: rate
      )
      convertedAmount = amountFormatter.formatAmount(
        converted.amount,
        fractionDigits: converted.fractionLength,
        maximumFractionDigits: 2,
        currency: currency
      )
    }
    
    return AssetBalance(
      assetSymbol: "",
      amount: amount,
      convertedAmount: convertedAmount
    )
  }
  
  func mapTokenListItem(_ tokenListItem: SwapTokenListItemsModel.Item) -> TokenButtonListItemsModel.Item {
    TokenButtonListItemsModel.Item(
      asset: tokenListItem.asset,
      image: tokenListItem.image
    )
  }
}
