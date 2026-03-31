import Foundation
import KeeperCore
import TKUIKit

struct RampPickerState {
    let mode: Mode
    let scrollToSelected: Bool

    enum Mode {
        case currency(currencies: [RemoteCurrency], selected: RemoteCurrency?)
        case crypto(items: [CryptoPickerItem], selectedId: String?)
        case paymentMethod(methods: [OnRampLayoutCashMethod])
        case network(assets: [OnRampLayoutCryptoMethod], stablecoinCode: String)
    }
}

struct CryptoPickerItem: Hashable {
    let identifier: String
    let symbol: String
    let networkName: String
    let network: String
    let image: TKImage?

    func hash(into hasher: inout Hasher) {
        hasher.combine(identifier)
    }

    static func == (lhs: CryptoPickerItem, rhs: CryptoPickerItem) -> Bool {
        lhs.identifier == rhs.identifier
    }
}

protocol RampPickerModel: AnyObject {
    var didUpdateState: ((RampPickerState?) -> Void)? { get set }

    func getState() -> RampPickerState?
}
