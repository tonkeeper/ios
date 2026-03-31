import TKUIKit
import UIKit

struct ChargeItem: AmountInputUnit {
    var inputSymbol: AmountInputSymbol {
        .icon(.TKUIKit.Icons.Vector.flash)
    }

    var fractionalDigits: Int {
        0
    }

    var symbol: String {
        ""
    }
}
