import BigInt
import Foundation
import TonAPI
import TonSwift

public struct SendTransactionModel {
    public let accountEvent: AccountEvent
    public let fee: Int64
    public let extra: Int64

    init(
        accountEvent: TonAPI.Components.Schemas.AccountEvent,
        risk: TonAPI.Components.Schemas.Risk,
        transaction: TonAPI.Components.Schemas.Transaction
    ) throws {
        self.accountEvent = try AccountEvent(accountEvent: accountEvent)
        self.fee = transaction.totalFees
        self.extra = accountEvent.extra
    }
}
