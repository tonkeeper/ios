import BigInt
import Foundation
import TKBatteryAPI
import TonSwift

extension BatteryBalance {
    init(balance: TKBatteryAPI.Balance) throws {
        self.balance = balance.balance
        self.reserved = balance.reserved
    }
}
