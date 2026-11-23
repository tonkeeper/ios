import Foundation
import KeeperCoreComponents
import KeeperCoreSensitive

public final class SecureAssembly {
    private let coreAssembly: CoreAssembly
    private let didUnlockMnemonics: @Sendable ([CoreMnemonicIdentifier: CoreMnemonic]) async -> Void

    init(
        coreAssembly: CoreAssembly,
        didUnlockMnemonics: @escaping @Sendable ([CoreMnemonicIdentifier: CoreMnemonic]) async -> Void = { _ in }
    ) {
        self.coreAssembly = coreAssembly
        self.didUnlockMnemonics = didUnlockMnemonics
    }

    public private(set) lazy var mnemonicAccess = createMnemonicAccess()

    private func createMnemonicAccess() -> MnemonicAccess {
        let raw = MnemonicsRawDataRepository(
            seedProvider: coreAssembly.seedProvider
        )
        return MnemonicAccess(
            mnemonicsRepository: MnemonicAccess.ModernRepository(
                raw: raw,
                unlocked: { passcode in
                    try raw.unlocked(passcode: passcode)
                }
            ),
            passcodeStorage: PasscodeStorage(seedProvider: coreAssembly.seedProvider),
            legacyRepository: MnemonicAccess.LegacyRepository(
                rn: coreAssembly.rnMnemonicsVault(),
                native: coreAssembly.mnemonicsVault()
            ),
            didUnlockMnemonics: didUnlockMnemonics
        )
    }
}
