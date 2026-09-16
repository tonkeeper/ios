import Foundation
import KeeperCoreSensitive
import TKLogging

public protocol TronWalletMigration {
    var needsMigration: Bool { get }

    @discardableResult
    func migrate(passcode: String) async -> Bool
}

struct TronWalletMigrationDependencies {
    var isMigrationCompleted: () -> Bool
    var completeMigration: () -> Void
    var getWallets: () -> [Wallet]
    var getMnemonics: (_ wallets: [Wallet], _ passcode: String) async throws -> [CoreMnemonicIdentifier: CoreMnemonic]
    var saveWalletTron: (_ wallet: Wallet, _ tron: WalletTron) async -> Void
}

struct TronWalletMigrationImplementation {
    private let dependencies: TronWalletMigrationDependencies

    init(dependencies: TronWalletMigrationDependencies) {
        self.dependencies = dependencies
    }
}

extension TronWalletMigrationImplementation: TronWalletMigration {
    var needsMigration: Bool {
        !dependencies.isMigrationCompleted() && !walletsNeedingMigration().isEmpty
    }

    func migrate(passcode: String) async -> Bool {
        guard !dependencies.isMigrationCompleted() else {
            return true
        }
        let wallets = walletsNeedingMigration()
        guard !wallets.isEmpty else {
            dependencies.completeMigration()
            return true
        }
        let mnemonicsByWalletId: [CoreMnemonicIdentifier: CoreMnemonic]
        do {
            mnemonicsByWalletId = try await dependencies.getMnemonics(wallets, passcode)
        } catch {
            Log.w("failed to load mnemonics for legacy tron migration due to error: \(error.localizedDescription)")
            return false
        }

        for wallet in wallets {
            guard !Task.isCancelled else {
                return false
            }
            guard let mnemonic = mnemonicsByWalletId[wallet.id] else {
                Log.w("failed to migrate legacy tron wallet due to missing mnemonic")
                continue
            }
            guard mnemonic.type == .ton else {
                continue
            }
            guard let tron = WalletTron(tonMnemonic: mnemonic.mnemonicWords) else {
                Log.w("failed to migrate legacy tron wallet due to derivation failure")
                continue
            }
            await dependencies.saveWalletTron(wallet, tron)
        }
        guard !Task.isCancelled else {
            return false
        }
        dependencies.completeMigration()
        return true
    }
}

private extension TronWalletMigrationImplementation {
    func walletsNeedingMigration() -> [Wallet] {
        dependencies.getWallets().filter { wallet in
            wallet.isTronAvailable && wallet.tron == nil && !wallet.isMultichain
        }
    }
}
