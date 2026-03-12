import Foundation
import KeeperCore
import TKLocalize

struct BatteryChargesMapper {
    private let batteryCalculation: BatteryCalculation

    init(batteryCalculation: BatteryCalculation) {
        self.batteryCalculation = batteryCalculation
    }

    func getChargesCountString(transaction: BatterySupportedTransaction, wallet: Wallet) -> String {
        let perPart: String
        let charges: String
        switch transaction {
        case .swap:
            perPart = TKLocales.Battery.Settings.Items.Swaps.caption
            if let chargesCount = batteryCalculation.calculateSwapsMinimumChargesAmount(network: wallet.network) {
                charges = "\u{2248} \(chargesCount) \(TKLocales.Battery.Refill.chargesCount(count: chargesCount))"
            } else {
                charges = "? \(TKLocales.Battery.Refill.Charges.many)"
            }
        case .jetton:
            perPart = TKLocales.Battery.Settings.Items.Token.caption
            if let chargesCount = batteryCalculation.calculateTokenTransferMinimumChargesAmount(network: wallet.network) {
                charges = "\u{2248} \(chargesCount) \(TKLocales.Battery.Refill.chargesCount(count: chargesCount))"
            } else {
                charges = "? \(TKLocales.Battery.Refill.Charges.many)"
            }
        case .nft:
            perPart = TKLocales.Battery.Settings.Items.Nft.caption
            if let chargesCount = batteryCalculation.calculateNFTTransferMinimumChargesAmount(network: wallet.network) {
                charges = "\u{2248} \(chargesCount) \(TKLocales.Battery.Refill.chargesCount(count: chargesCount))"
            } else {
                charges = "? \(TKLocales.Battery.Refill.Charges.many)"
            }
        case .trc20:
            perPart = TKLocales.Battery.Settings.Items.Trc20.caption
            if let min = batteryCalculation.calculateTRC20MinimumChargesAmount(network: wallet.network),
               let max = batteryCalculation.calculateTRC20MaximumChargesAmount(network: wallet.network)
            {
                charges = "\u{2248} \(min) - \(max) \(TKLocales.Battery.Refill.chargesCount(count: max))"
            } else {
                charges = "? \(TKLocales.Battery.Refill.Charges.many)"
            }
        }
        return "\(charges) \(perPart)"
    }
}
