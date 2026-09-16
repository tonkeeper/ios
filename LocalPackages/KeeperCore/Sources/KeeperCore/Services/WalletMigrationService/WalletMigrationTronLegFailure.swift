import Foundation
import TronSwiftAPI

/// Classifies a failed TRON migration leg in one place. Build and broadcast report the same
/// conditions differently, and the difference the user sees — a top-up prompt, "activate the
/// account", or the node's own exception text — hangs entirely on telling them apart.
enum WalletMigrationTronLegFailure {
    static func map(_ error: Swift.Error) -> WalletMigrationExecutionError {
        switch error {
        case is TronTransferSignError:
            return .signingFailed
        case let error as WalletMigrationExecutionError:
            return error
        case let error as TronApi.Error where error.isInactiveTronAccount:
            return .inactiveTronAccount
        case let error as TronApi.Error where error.isInsufficientTronResources:
            return .insufficientTronFee
        default:
            return .sendFailed(message: error.localizedDescription)
        }
    }
}
