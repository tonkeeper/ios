import Foundation
import KeeperCoreComponents
import TKKeychain

public protocol MnemonicsRepository {
    func hasMnemonics() -> Bool
    func getMnemonic(
        wallet: Wallet,
        password: String
    ) async throws -> KeeperCoreComponents.Mnemonic
    func saveMnemonic(
        _ mnemonic: KeeperCoreComponents.Mnemonic,
        wallet: Wallet,
        password: String
    ) async throws
    func saveMnemonic(
        _ mnemonic: KeeperCoreComponents.Mnemonic,
        wallets: [Wallet],
        password: String
    ) async throws
    func deleteMnemonic(
        wallet: Wallet,
        password: String
    ) async throws
    func checkIfPasswordValid(_ password: String) async -> Bool
    func changePassword(oldPassword: String, newPassword: String) async throws
    func deleteAll() async throws

    func savePassword(_ password: String) throws
    func getPassword() throws -> String
    func deletePassword() throws

    /// Non-interactive probe of the biometry-protected password item, to tell an
    /// invalidated enrolled set apart from a plain absent item.
    func probeBiometryAccess() -> TKKeychainBiometryAccess
    /// Whether the password item already uses `biometryCurrentSet`; `false` means a
    /// legacy `biometryAny` item still needs the one-time migration.
    func isBiometryItemMigrated() -> Bool
}

public extension MnemonicsRepository {
    /// Conservative defaults for repositories that don't expose a
    /// biometryCurrentSet password item (e.g. the RN vault): treat as
    /// indeterminate / already-migrated so the recovery + lazy-migration paths
    /// stay inert. `MnemonicsVault` overrides both with real implementations.
    func probeBiometryAccess() -> TKKeychainBiometryAccess {
        .indeterminate
    }

    func isBiometryItemMigrated() -> Bool {
        true
    }
}

extension RNMnemonicsVault: MnemonicsRepository {
    public func getMnemonic(wallet: Wallet, password: String) async throws -> KeeperCoreComponents.Mnemonic {
        try await getMnemonic(identifier: wallet.id, password: password)
    }

    public func saveMnemonic(_ mnemonic: KeeperCoreComponents.Mnemonic, wallet: Wallet, password: String) async throws {
        try await addMnemonic(mnemonic, identifier: wallet.id, password: password)
    }

    public func saveMnemonic(_ mnemonic: KeeperCoreComponents.Mnemonic, wallets: [Wallet], password: String) async throws {
        let vaultMnemonics = Dictionary(uniqueKeysWithValues: wallets.map { ($0.id, mnemonic) })
        try await addMnemonics(vaultMnemonics, password: password)
    }

    public func deleteMnemonic(wallet: Wallet, password: String) async throws {
        try await deleteMnemonic(identifier: wallet.id, password: password)
    }

    public func checkIfPasswordValid(_ password: String) async -> Bool {
        do {
            try await validatePassword(password)
            return true
        } catch {
            return false
        }
    }
}

extension MnemonicsVault: MnemonicsRepository {
    public func getMnemonic(wallet: Wallet, password: String) async throws -> KeeperCoreComponents.Mnemonic {
        try await getMnemonic(identifier: wallet.id, password: password)
    }

    public func saveMnemonic(_ mnemonic: KeeperCoreComponents.Mnemonic, wallet: Wallet, password: String) async throws {
        try await addMnemonic(mnemonic, identifier: wallet.id, password: password)
    }

    public func saveMnemonic(_ mnemonic: KeeperCoreComponents.Mnemonic, wallets: [Wallet], password: String) async throws {
        let vaultMnemonics = Dictionary(uniqueKeysWithValues: wallets.map { ($0.id, mnemonic) })
        try await addMnemonics(vaultMnemonics, password: password)
    }

    public func deleteMnemonic(wallet: Wallet, password: String) async throws {
        try await deleteMnemonic(identifier: wallet.id, password: password)
    }

    public func checkIfPasswordValid(_ password: String) async -> Bool {
        do {
            try await validatePassword(password)
            return true
        } catch {
            return false
        }
    }
}
