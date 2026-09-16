import TKUIKit
import UIKit

struct ChargeItem: AmountInputUnit {
    var inputSymbol: AmountInputSymbol {
        .icon(.TKUIKit.Icons.Size16.batteryFlash)
    }

    var fractionalDigits: Int {
        0
    }

    var symbol: String {
        ""
    }
}
