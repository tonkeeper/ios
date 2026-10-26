import BigInt

/// None of the fee methods a USD₮ TRC20 transfer offers can pay.
public struct TronFeeShortage: Equatable {
    /// The TRX fee, in sun.
    public let requiredTRX: BigUInt
    public let isBatteryOffered: Bool
}

/// A legacy TRON account's options are never marked `isInsufficient`, so the caller weighs them.
public extension TransactionConfirmationModel {
    /// TRX, the chain's own coin, goes first, as in the multichain controller.
    func payableTronFeeType(isInsufficient: (ExtraOption) -> Bool) -> ExtraType? {
        guard case let .extra(extra) = extraState,
              let selected = extraOptions.first(where: { $0.type == extra.value.extraType }),
              isInsufficient(selected)
        else {
            return nil
        }
        let payable = extraOptions.filter { !isInsufficient($0) }
        return (payable.first { $0.type.isTRXGasless } ?? payable.first)?.type
    }

    func tronFeeShortage(isInsufficient: (ExtraOption) -> Bool) -> TronFeeShortage? {
        switch transaction {
        case .transfer(.tronUSDT), .transfer(.multichain):
            break
        default:
            return nil
        }
        guard case .extra = extraState,
              let trxOption = extraOptions.first(where: { $0.type.isTRXGasless }),
              case let .gasless(_, requiredTRX) = trxOption.value,
              extraOptions.allSatisfy(isInsufficient)
        else {
            return nil
        }
        return TronFeeShortage(
            requiredTRX: requiredTRX,
            isBatteryOffered: extraOptions.contains { $0.type.isBattery }
        )
    }
}
