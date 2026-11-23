import Foundation

struct BatteryPaymentPreparation {
    struct Prepared {
        let passcode: String

        var signer: MultichainTransferSigner {
            .mnemonic(passcodeProvider: { Task.isCancelled ? nil : passcode })
        }
    }

    var needsMigration: (Wallet) async throws -> Bool = { _ in false }
    var migrate: (Wallet, String) async throws -> Void = { _, _ in }
    var currentCharges: (Wallet) async -> BatteryChargesAvailability = { _ in .unknown }

    func prepare(wallet: Wallet, signer: MultichainTransferSigner, requiredCharges: Int? = nil) async throws -> Prepared? {
        guard case let .mnemonic(passcodeProvider) = signer,
              try await needsMigration(wallet)
        else { return nil }
        if let requiredCharges, case let .available(charges) = await currentCharges(wallet), charges >= requiredCharges {
            return nil
        }
        guard let passcode = await passcodeProvider() else { throw CancellationError() }
        try Task.checkCancellation()
        try await migrate(wallet, passcode)
        try Task.checkCancellation()
        return Prepared(passcode: passcode)
    }
}
