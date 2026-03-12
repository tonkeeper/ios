import Foundation
import KeeperCore
import TonSwift

struct TokenPickerModelState {
    let wallet: Wallet
    let tonBalance: ConvertedTonBalance?
    let jettonBalances: [ConvertedJettonBalance]
    let tronUSDTBalance: ConvertedBalanceTronUSDTItem?
    let selectedToken: PickerToken
    let scrollToSelected: Bool
    let mode: PickerMode

    enum PickerToken {
        case ton(TonToken)
        case tronUSDT
    }

    enum PickerMode {
        case balance(showConverted: Bool, currency: Currency? = nil)
        case name
    }
}

protocol TokenPickerModel: AnyObject {
    var didUpdateState: ((TokenPickerModelState?) -> Void)? { get set }

    func getState() -> TokenPickerModelState?
}
