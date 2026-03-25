import Foundation
import KeeperCore

public typealias RampAsset = OnRampLayoutToken

extension OnRampLayoutToken: AmountInputUnit {
    var inputSymbol: AmountInputSymbol {
        .text(symbol)
    }

    var fractionalDigits: Int {
        decimals
    }
}
