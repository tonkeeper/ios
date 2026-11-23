import BigInt
import Foundation
import KeeperCore

struct BatteryRechargeAsset {
    struct Pack {
        let id: String
        let charges: Int
    }

    let method: BatteryAssetRechargeMethod
    let asset: MultichainAsset
    let sender: String
    let chargeCost: String?
    let packages: [Pack]
    var isReady = true

    var rate: Decimal? {
        guard let chargeCost else { return nil }
        return method.chargesPerUnit(chargeCost: chargeCost)
    }

    var minimum: BigUInt? {
        BatteryRechargeMath.minimumUnits(method.minimum, decimals: method.decimals)
    }

    func amount(for pack: Pack) -> BigUInt? {
        rate.flatMap { BatteryRechargeMath.amount(charges: pack.charges, rate: $0, decimals: method.decimals) }
    }

    func fiatAmount(_ amount: BigUInt, currency: Currency) -> Decimal? {
        guard let value = BatteryRechargeMath.value(amount, decimals: method.decimals),
              let price = asset.price.value(for: currency.code) else { return nil }
        return value * Decimal(price)
    }

    func canBuy(_ amount: BigUInt) -> Bool {
        guard isReady, let minimum else { return false }
        return amount > 0 && amount >= minimum && amount <= asset.balance
    }
}
