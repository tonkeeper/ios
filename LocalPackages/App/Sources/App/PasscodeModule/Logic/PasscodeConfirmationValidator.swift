import Foundation
import KeeperCore
import KeeperCoreSensitive

struct PasscodeConfirmationValidator: PasscodeInputValidator {
    private let mnemonicAccess: MnemonicAccess

    init(mnemonicAccess: MnemonicAccess) {
        self.mnemonicAccess = mnemonicAccess
    }

    func validate(passcode: String) async -> PasscodeInputValidationResult {
        await mnemonicAccess.validatePasscode(passcode) ? .success : .failed
    }

    func getPasscode() throws -> String {
        try mnemonicAccess.getPasscode()
    }

    func resetPasscodeStorage() throws {
        try mnemonicAccess.deletePasscode()
    }

    func refreshStoredPasscode(_ passcode: String) throws {
        try mnemonicAccess.setPasscode(passcode)
    }

    func biometryAccessProbe() -> BiometryAccessProbe {
        switch mnemonicAccess.biometryAccessProbe() {
        case .accessible:
            return .satisfiable
        case .invalidated:
            return .invalidated
        case .missing, .indeterminate:
            return .indeterminate
        }
    }

    func isBiometryItemMigrated() -> Bool {
        mnemonicAccess.isBiometryItemMigrated()
    }
}
