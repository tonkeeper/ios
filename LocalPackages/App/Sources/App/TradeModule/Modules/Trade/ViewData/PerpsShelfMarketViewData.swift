import Foundation
import TKUIKit

struct PerpsShelfMarketViewData: Identifiable {
    let id: Int64
    let symbol: String
    let iconURL: URL?
    let leverage: String
    let changeText: String?
    let changeColor: TKColor
}
