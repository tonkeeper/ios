import BigInt
import Foundation
import KeeperCore

struct BatteryRechargePayload {
    let token: TonToken
    let amount: BigUInt
    let promocode: String?
    let recipient: TonRecipient?
}
