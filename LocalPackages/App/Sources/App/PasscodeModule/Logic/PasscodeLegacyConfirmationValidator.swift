import Foundation
import KeeperCore
import TKKeychain

struct PasscodeLegacyConfirmationValidator: PasscodeInputValidator {
    private let mnemonicsRepository: MnemonicsRepository

    init(mnemonicsRepository: MnemonicsRepository) {
        self.mnemonicsRepository = mnemonicsRepository
    }

    func validate(passcode: String) async -> PasscodeInputValidationResult {
        await mnemonicsRepository.checkIfPasswordValid(passcode) ? .success : .failed
    }

    func getPasscode() throws -> String {
        try mnemonicsRepository.getPassword()
    }

    func resetPasscodeStorage() throws {
        try mnemonicsRepository.deletePassword()
    }

    func refreshStoredPasscode(_ passcode: String) throws {
        try mnemonicsRepository.savePassword(passcode)
    }

    func biometryAccessProbe() -> BiometryAccessProbe {
        switch mnemonicsRepository.probeBiometryAccess() {
        case .accessible:
            return .satisfiable
        case .invalidated:
            return .invalidated
        case .missing, .indeterminate:
            // On device an invalidated biometryCurrentSet item reads as not-found;
            // the non-biometric "migrated" marker tells that apart from a cache
            // that is genuinely gone (a storage-version rollback drops it), and a
            // present non-biometry wallet confirms the cache was in use. Same
            // marker gate as MnemonicAccess.biometryAccessProbe, which keeps
            // `.indeterminate` as-is rather than folding it in here.
            guard mnemonicsRepository.isBiometryItemMigrated() else {
                return .indeterminate
            }
            return mnemonicsRepository.hasMnemonics() ? .invalidated : .indeterminate
        }
    }

    func isBiometryItemMigrated() -> Bool {
        mnemonicsRepository.isBiometryItemMigrated()
    }
}
