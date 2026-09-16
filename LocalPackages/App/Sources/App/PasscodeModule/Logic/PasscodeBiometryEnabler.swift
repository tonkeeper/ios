import Foundation
import KeeperCore
import TKLogging

struct PasscodeBiometryEnabler {
    private let mnemonicAccess: MnemonicAccess
    private let securityStore: SecurityStore
    private let biometryProvider: BiometryProvider

    init(
        mnemonicAccess: MnemonicAccess,
        securityStore: SecurityStore,
        biometryProvider: BiometryProvider = BiometryProvider()
    ) {
        self.mnemonicAccess = mnemonicAccess
        self.securityStore = securityStore
        self.biometryProvider = biometryProvider
    }

    func offerBiometry(passcode: String) async {
        guard biometryProvider.isAvailable else { return }

        do {
            try mnemonicAccess.setPasscode(passcode)
            _ = try mnemonicAccess.getPasscode()
            await securityStore.setIsBiometryEnable(true)
        } catch {
            Log.w("Biometry offer declined or failed", extraInfo: [
                "error": error.localizedDescription,
            ])
        }
    }
}
