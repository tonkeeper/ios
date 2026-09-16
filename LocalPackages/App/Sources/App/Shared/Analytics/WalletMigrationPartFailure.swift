import KeeperCore
import TKCore

struct WalletMigrationPartFailure: Error {
    let part: MigrationPart
    let isPartial: Bool
    let underlying: Error
}

func withMigrationPart(
    _ part: MigrationPart,
    isPartial: Bool,
    _ body: () async throws -> Void
) async throws {
    do {
        try await body()
    } catch is CancellationError {
        throw CancellationError()
    } catch {
        let hasSentTransactions = (error as? WalletMigrationExecutionError)?.hasSentTransactions == true
        throw WalletMigrationPartFailure(
            part: part,
            isPartial: isPartial || hasSentTransactions,
            underlying: error
        )
    }
}
