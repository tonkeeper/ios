import Foundation
import KeeperCore
import TonSwift
import TronSwift

extension Rates {
    func rate(
        for asset: TradingAssetToken,
        in currency: Currency
    ) -> Rate? {
        let values: [Rates.Rate]
        switch asset {
        case .ton:
            values = ton
        case .tronUsdt:
            values = usdt
        case .tronTrx:
            values = jettonRates
                .first {
                    $0.key.caseInsensitiveCompare(TRX.symbol) == .orderedSame
                }?
                .value ?? []
        case let .jetton(address):
            if address == JettonMasterAddress.tonUSDT {
                values = usdt
            } else {
                values = jettonRates
                    .first {
                        $0.key.caseInsensitiveCompare(address.toRaw()) == .orderedSame
                    }?
                    .value ?? []
            }
        }
        return values
            .first {
                $0.currency == currency
            }
    }
}
