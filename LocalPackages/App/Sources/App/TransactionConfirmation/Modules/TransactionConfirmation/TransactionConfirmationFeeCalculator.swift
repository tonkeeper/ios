import BigInt
import Foundation
import KeeperCore
import TronSwift

struct TransactionConfirmationFeeCalculator {
    enum TokenKind {
        case ton
        case trx
        case other
    }

    enum FeeKind {
        case battery(charges: Int?, excess: Int?, estimatedTONAmount: BigUInt?)
        case token(amount: BigUInt, fractionDigits: Int, symbol: String, tokenKind: TokenKind)
    }

    struct FeeDetails {
        let isRefund: Bool
        let extraType: TransactionConfirmationModel.ExtraType
        let kind: FeeKind
    }

    private let configuration: Configuration

    init(configuration: Configuration) {
        self.configuration = configuration
    }

    func feeDetails(
        extra: TransactionConfirmationModel.Extra,
        wallet: Wallet
    ) -> FeeDetails {
        FeeDetails(
            isRefund: extra.kind == .refund,
            extraType: extra.value.extraType,
            kind: feeKind(value: extra.value, wallet: wallet)
        )
    }

    func feeKind(
        value: TransactionConfirmationModel.ExtraValue,
        wallet: Wallet
    ) -> FeeKind {
        switch value {
        case let .battery(charges, excess):
            let estimatedTONAmount = charges.flatMap {
                batteryTONFeeAmount(charges: $0, network: wallet.network)
            }
            return .battery(
                charges: charges,
                excess: excess,
                estimatedTONAmount: estimatedTONAmount
            )
        case let .default(amount):
            return .token(
                amount: amount,
                fractionDigits: TonInfo.fractionDigits,
                symbol: TonInfo.symbol,
                tokenKind: .ton
            )
        case let .gasless(token, amount):
            let tokenKind: TokenKind = token.symbol?.uppercased() == TRX.symbol.uppercased() ? .trx : .other
            return .token(
                amount: amount,
                fractionDigits: token.fractionDigits,
                symbol: token.symbol ?? token.name,
                tokenKind: tokenKind
            )
        }
    }

    private func batteryTONFeeAmount(
        charges: Int,
        network: Network
    ) -> BigUInt? {
        guard let batteryMeanFee = configuration.batteryMeanFeesDecimaNumber(network: network) else {
            return nil
        }

        let tonAmount = batteryMeanFee.multiplying(by: NSDecimalNumber(value: charges))
        let nanoAmount = tonAmount
            .multiplying(byPowerOf10: Int16(TonInfo.fractionDigits))
            .rounding(
                accordingToBehavior: NSDecimalNumberHandler(
                    roundingMode: .up,
                    scale: 0,
                    raiseOnExactness: false,
                    raiseOnOverflow: false,
                    raiseOnUnderflow: false,
                    raiseOnDivideByZero: false
                )
            )
        return BigUInt(nanoAmount.stringValue)
    }
}
