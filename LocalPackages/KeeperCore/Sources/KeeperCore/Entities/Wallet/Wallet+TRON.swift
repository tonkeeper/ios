import Foundation
import TronSwift

public extension Wallet {
    var isTronAvailable: Bool {
        kind == .regular && network == .mainnet
    }
}
