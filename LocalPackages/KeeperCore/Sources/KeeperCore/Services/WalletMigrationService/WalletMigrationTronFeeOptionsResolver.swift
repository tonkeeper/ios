import BigInt
import Foundation
import TronSwift

enum WalletMigrationTronFeeOptionsResolver {
    static func resolve(
        availableTypes: [TransactionConfirmationModel.ExtraType],
        requiredBatteryCharges: Int,
        requiredTRXSun: BigUInt,
        isAccountActivated: Bool = true
    ) -> [WalletMigrationTronPrepareResult.FeeMethod] {
        guard isAccountActivated else {
            return [.trx(amountSun: requiredTRXSun)]
        }
        return availableTypes.compactMap { type in
            switch type {
            case .battery where requiredBatteryCharges > 0:
                return .battery(charges: requiredBatteryCharges)
            case let .gasless(token) where token.symbol?.uppercased() == TRX.symbol.uppercased():
                return .trx(amountSun: requiredTRXSun)
            case .battery, .default, .gasless, .multichain:
                return nil
            }
        }
    }
}
