import Foundation
import TronSwift

public extension Wallet {
    enum TronUSDTError: Swift.Error {
        case addressFailed
    }

    var isTronAvailable: Bool {
        kind == .regular && network == .mainnet
    }

    var isTronTurnOn: Bool {
        tron?.isOn == true
    }
}
