import Foundation
import KeeperCoreComponents
import KeeperCoreSensitive
import TKLogging

public final class SecureAssembly {
    private let coreAssembly: CoreAssembly
    private let configurationAssembly: ConfigurationAssembly

    init(
        coreAssembly: CoreAssembly,
        configurationAssembly: ConfigurationAssembly
    ) {
        self.coreAssembly = coreAssembly
        self.configurationAssembly = configurationAssembly
    }

    public private(set) lazy var mnemonicAccess = createMnemonicAccess()

    private func createMnemonicAccess() -> MnemonicAccess {
        let legacy = MnemonicAccess.LegacyRepository(
            rn: coreAssembly.rnMnemonicsVault(),
            native: coreAssembly.mnemonicsVault()
        )
        if configurationAssembly.configuration.featureEnabled(.mnemonicsStorageV2) {
            let raw = MnemonicsRawDataRepository(
                seedProvider: coreAssembly.seedProvider
            )
            let modern = MnemonicAccess.ModernRepository(
                raw: raw,
                unlocked: { passcode in
                    try raw.unlocked(passcode: passcode)
                }
            )
            return .v2(
                mnemonicsRepository: modern,
                passcodeStorage: PasscodeStorage(seedProvider: coreAssembly.seedProvider),
                legacyRepository: legacy
            )
        } else {
            let raw = MnemonicsRawDataRepository(
                seedProvider: coreAssembly.seedProvider
            )
            do {
                try raw.deleteAllKnownStorageArtifacts()
            } catch {
                Log.e("🪵 failed to delete v2 storage artifacts while storage v2 is disabled: \(error)")
            }
            let passcodeStorage = PasscodeStorage(seedProvider: coreAssembly.seedProvider)
            do {
                try passcodeStorage.deleteAllKnownStorageArtifacts()
            } catch {
                Log.e("🪵 failed to delete v2 passcode storage artifacts while storage v2 is disabled: \(error)")
            }
            return .disabled(
                mnemonicsRepository: legacy
            )
        }
    }
}
