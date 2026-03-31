import BigInt
import Foundation
import TKBatteryAPI
import TonSwift

extension BatteryBalance {
    init(balance: Components.Schemas.Balance) {
        self.balance = balance.balance
        self.reserved = balance.reserved
    }
}
