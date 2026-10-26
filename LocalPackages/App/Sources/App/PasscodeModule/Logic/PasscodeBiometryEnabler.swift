import Foundation
import KeeperCore
import TKLogging

struct PasscodeBiometryEnabler {
    private let mnemonicAccess: MnemonicAccess
    private let biometryProvider: BiometryProvider

    init(
        mnemonicAccess: MnemonicAccess,
        biometryProvider: BiometryProvider = BiometryProvider()
    ) {
        self.mnemonicAccess = mnemonicAccess
        self.biometryProvider = biometryProvider
    }

    /// Shows the system biometry prompt and returns whether it unlocked the stored passcode.
    /// The caller turns the biometry setting on once the first wallet is added: the settings
    /// live in the wallets' `KeeperInfo`, so an earlier write is dropped.
    func offerBiometry(passcode: String) async -> Bool {
        guard biometryProvider.isAvailable else { return false }

        do {
            try await mnemonicAccess.setBiometryProtectedPasscode(passcode)
            return true
        } catch {
            Log.w("Biometry offer declined or failed", extraInfo: [
                "error": error.localizedDescription,
            ])
            return false
        }
    }
}
