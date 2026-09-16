import BigInt
import TronSwift

/// Balances the fee decision is made against. `nil` means "unknown" — the request failed and
/// nothing was cached — and is deliberately different from a loaded zero balance.
struct MultichainFeeBalances {
    let batteryCharges: BatteryChargesAvailability
    let ton: BigUInt?
    let trx: BigUInt?
    let jettonForwardAmount: BigUInt

    init(
        batteryCharges: BatteryChargesAvailability,
        ton: BigUInt?,
        trx: BigUInt?,
        jettonForwardAmount: BigUInt = 0
    ) {
        self.batteryCharges = batteryCharges
        self.ton = ton
        self.trx = trx
        self.jettonForwardAmount = jettonForwardAmount
    }
}

/// Decides which fee options a multichain transfer can actually pay with, and which one to preselect.
struct MultichainFeeSelection {
    let engine: MultichainFeeEngineResolver.Engine
    let transferAmount: BigUInt

    func annotatingInsufficiency(
        _ extraOptions: [TransactionConfirmationModel.ExtraOption],
        balances: MultichainFeeBalances
    ) -> [TransactionConfirmationModel.ExtraOption] {
        extraOptions.map { option in
            TransactionConfirmationModel.ExtraOption(
                type: option.type,
                value: option.value,
                isInsufficient: isInsufficient(option.value, balances: balances)
            )
        }
    }

    /// TRX is the natural fee asset for a TRON transfer, so it wins over the TON-billed option once
    /// Battery cannot pay — but only while the wallet covers it, otherwise preselecting it leaves
    /// the user on an unpayable method.
    func trxTypeToPreselect(
        in extraOptions: [TransactionConfirmationModel.ExtraOption],
        hasUserSelectedFeeMethod: Bool
    ) -> TransactionConfirmationModel.ExtraType? {
        guard case .tronUSDT = engine,
              !hasUserSelectedFeeMethod,
              let batteryOption = extraOptions.first(where: { $0.type.isBattery }),
              batteryOption.isInsufficient,
              let trxOption = extraOptions.first(where: { $0.type.isTRXGasless }),
              !trxOption.isInsufficient
        else {
            return nil
        }
        return trxOption.type
    }

    private func isInsufficient(
        _ extraValue: TransactionConfirmationModel.ExtraValue,
        balances: MultichainFeeBalances
    ) -> Bool {
        switch extraValue {
        case let .battery(charges, _):
            switch balances.batteryCharges {
            case .unavailable:
                return true
            case .unknown:
                return false
            case let .available(availableCharges):
                return charges.map { availableCharges < $0 } ?? false
            }

        case let .default(amount):
            let requiredTonBalance: BigUInt
            switch engine {
            case .tronUSDT:
                // Fee is paid via a separate TON transfer that needs its own gas buffer.
                requiredTonBalance = TronUSDTTonFeePaymentBuilder.requiredTonBalance(for: amount)
            case .tonJetton:
                // Wallet must hold the emulated fee plus the forward amount attached to the jetton message.
                requiredTonBalance = amount + balances.jettonForwardAmount
            case .chainKit:
                requiredTonBalance = amount
            }
            return balances.ton.map { $0 < requiredTonBalance } ?? false

        case let .gasless(_, feeAmount):
            switch engine {
            case .tronUSDT:
                // Fee is paid from the native TRX balance.
                return balances.trx.map { $0 < feeAmount } ?? false
            case .tonJetton:
                // Gasless fee is deducted from the transferred jetton, so it must be
                // smaller than the amount being sent (mirrors the engine's own guard).
                return feeAmount >= transferAmount
            case .chainKit:
                return false
            }

        case .multichain:
            return false
        }
    }
}

extension TransactionConfirmationModel.ExtraType {
    var isBattery: Bool {
        guard case .battery = self else {
            return false
        }
        return true
    }

    var isTRXGasless: Bool {
        guard case let .gasless(token) = self else {
            return false
        }
        return token.symbol?.uppercased() == TRX.symbol.uppercased()
    }
}
