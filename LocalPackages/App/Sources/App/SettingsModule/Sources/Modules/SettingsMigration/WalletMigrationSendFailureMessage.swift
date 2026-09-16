import Foundation
import KeeperCore

enum WalletMigrationSendFailureMessage {
    static func extract(from error: Error) -> String? {
        let underlying = (error as? WalletMigrationPartFailure)?.underlying ?? error
        guard let executionError = underlying as? WalletMigrationExecutionError else {
            return nil
        }
        switch executionError {
        case let .sendFailed(message), let .partiallySent(message):
            let text = message.trimmingCharacters(in: .whitespacesAndNewlines)
            return text.isEmpty ? nil : text
        case .emptyTransactions,
             .unsupportedWalletKind,
             .signingFailed,
             .tronAddressUnavailable,
             .insufficientTronFee,
             .inactiveTronAccount:
            return nil
        }
    }
}
