import TKUIKit
import UIKit

struct PerpsShelfMarketViewData: Identifiable {
    let id: Int64
    let symbol: String
    let iconURL: URL?
    let leverage: String
    let changeText: String?
    let changeColor: TKColor
}

extension PerpsShelfMarketViewData {
    var leverageTag: TKTagSwiftUIViewConfig {
        TKTagSwiftUIViewConfig(
            text: leverage,
            style: .plain,
            textPadding: UIEdgeInsets(top: 0.5, left: 4, bottom: 1.5, right: 4),
            backgroundPadding: UIEdgeInsets(top: 2, left: 2, bottom: 2, right: 0)
        )
    }
}
