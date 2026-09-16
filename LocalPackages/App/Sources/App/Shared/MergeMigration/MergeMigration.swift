import Foundation
import KeeperCore
import KeeperCoreComponents
import KeeperCoreSensitive
import TKCore
import TKLogging
import TKUIKit
import TonSwift

struct MergeMigration {
    enum MigrationResult {
        case failedMigrateMnemonics(error: MnemonicMigrationError)
        case failedMigrateWallets(error: WalletsMigrationError)
        case partialy(failedWallets: [RNWallet])
        case success
    }

    enum MnemonicMigrationError: Swift.Error {
        case noMnemonics
        case readStorageError(Swift.Error)
        case importError(Swift.Error)
    }

    struct PasscodeFetchHandler {
        var validator: PasscodeInputValidator
        var onSuccess: (String) -> Void
    }

    enum WalletsMigrationResult {
        case success(failedWallets: [RNWallet])
        case failure(error: WalletsMigrationError)
    }

    enum WalletsMigrationError: Swift.Error {
        case noWallets
        case failedWalletsMigration(wallet: [RNWallet])
        case importError(Swift.Error)
    }

    private let asyncStorage: RNAsyncStorage
    private let appInfoProvider: TKCore.AppInfoProvider
    private let mnemonicsAccess: MnemonicAccess
    private let keeperInfoRepository: KeeperInfoRepository
    private let keeperInfoStore: KeeperInfoStore
    private let securityStore: SecurityStore
    private let tonProofTokenService: TonProofTokenService
    private let logger = LogDomain.mnemonicStorage

    init(
        asyncStorage: RNAsyncStorage,
        appInfoProvider: TKCore.AppInfoProvider,
        mnemonicsAccess: MnemonicAccess,
        keeperInfoRepository: KeeperInfoRepository,
        keeperInfoStore: KeeperInfoStore,
        securityStore: SecurityStore,
        tonProofTokenService: TonProofTokenService
    ) {
        self.asyncStorage = asyncStorage
        self.appInfoProvider = appInfoProvider
        self.mnemonicsAccess = mnemonicsAccess
        self.keeperInfoRepository = keeperInfoRepository
        self.keeperInfoStore = keeperInfoStore
        self.securityStore = securityStore
        self.tonProofTokenService = tonProofTokenService
    }

    func isNeedToMigrateFromRN() async -> Bool {
        do {
            if let xFlag: Bool = try await asyncStorage.getValue(key: "x"),
               xFlag
            {
                logger.i("🪵 rn migration skipped: completion flag is set")
                return false
            }
        } catch {
            logger.e("🪵 rn migration check failed to read completion flag: \(error)")
        }

        do {
            guard let walletsStore: RNWalletsStore = try await asyncStorage.getValue(key: .rnWalletsStoreKey) else {
                logger.i("🪵 rn migration check: wallets store is missing")
                return false
            }
            let needsMigration = !walletsStore.wallets.isEmpty
            logger.i("🪵 rn migration check: wallets=\(walletsStore.wallets.count), needsMigration=\(needsMigration)")
            return needsMigration
        } catch {
            logger.e("🪵 rn migration check failed to read wallets store: \(error)")
            return false
        }
    }

    enum MnemonicsVersion {
        case rn
        case native
        case nativeV2
    }

    enum NativeMigrationCheck {
        case ready(version: MnemonicsVersion)
        case needsMigration(from: MnemonicsVersion)
        case blocked(MnemonicMigrationError)
    }

    private enum V2MigrationState {
        case ready
        case needsMigration
        case blocked(Swift.Error)
    }

    func currentMnemonicsMigrationCheck() -> NativeMigrationCheck {
        switch mnemonicsAccess {
        case let .v2(_, _, legacyRepository):
            if legacyRepository.rn.hasMnemonics(), !legacyRepository.native.hasMnemonics() {
                logger.i(
                    "🪵 native migration check (v2): current version=\(MnemonicsVersion.rn)"
                )
                return .needsMigration(from: .rn)
            }

            switch v2MigrationState() {
            case .ready:
                logger.i(
                    "🪵 native migration check (v2): current version=\(MnemonicsVersion.nativeV2)"
                )
                return .ready(version: .nativeV2)
            case .needsMigration:
                logger.i(
                    "🪵 native migration check (v2): current version=\(MnemonicsVersion.native)"
                )
                return .needsMigration(from: .native)
            case let .blocked(error):
                logger.e("🪵 native migration check (v2) blocked: \(error)")
                return .blocked(.readStorageError(error))
            }
        case let .disabled(legacyRepository):
            if legacyRepository.rn.hasMnemonics(), !legacyRepository.native.hasMnemonics() {
                logger.i("🪵 native migration check (legacy): current version=\(MnemonicsVersion.rn)")
                return .needsMigration(from: .rn)
            } else {
                logger.i("🪵 native migration check (legacy): current version=\(MnemonicsVersion.native)")
                return .ready(version: .native)
            }
        }
    }

    private func v2MigrationState() -> V2MigrationState {
        guard case let .v2(mnemonicsRepository, _, legacyRepository) = mnemonicsAccess else {
            return .ready
        }
        let hasLegacyMnemonics = legacyRepository.native.hasMnemonics()
        let hasReadyV2Storage: Bool
        do {
            hasReadyV2Storage = try mnemonicsRepository.raw.hasCommittedStorage()
        } catch {
            logger.e("🪵 failed to read v2 committed storage state: \(error)")
            logger.i("🪵 v2 migration check: committed state read failed unexpectedly, preserving v2 storage artifacts, blocked=true")
            return .blocked(error)
        }

        guard hasLegacyMnemonics else {
            if hasReadyV2Storage {
                logger.i("🪵 v2 migration check: legacy storage is empty, v2Committed=true, needsMigration=false")
            } else {
                logger.i("🪵 v2 migration check: legacy storage is empty, v2Committed=false, needsMigration=false")
            }
            return .ready
        }

        guard hasLegacyMnemonics && !hasReadyV2Storage else {
            logger.i(
                "🪵 v2 migration check: legacyHasData=\(hasLegacyMnemonics), v2Committed=\(hasReadyV2Storage), needsMigration=false"
            )
            return .ready
        }

        logger.i("🪵 v2 migration check: v2 storage has no committed active slot")
        return .needsMigration
    }

    func performNativeMigration(
        from currentVersion: MnemonicsVersion,
        passcode: @escaping (PasscodeFetchHandler) -> Void,
        completion: @escaping (MigrationResult) -> Void
    ) {
        logger.i("🪵 starting native migration flow")
        let mnemonicsMigrationResult: Result<Void, MnemonicMigrationError>
        if case .rn = currentVersion {
            mnemonicsMigrationResult = migrateMnemonicsFromRnToNative()
        } else {
            mnemonicsMigrationResult = .success(())
        }
        switch mnemonicsMigrationResult {
        case .success:
            migratePasscodeRequiredItemsBiometryPasscode(passcode: passcode) { result in
                switch result {
                case .success:
                    logger.i("🪵 native migration completed successfully")
                    completion(.success)
                case let .failure(error):
                    logger.e("🪵 native migration failed on passcode-required step: \(error)")
                    completion(.failedMigrateMnemonics(error: error))
                }
            }
        case let .failure(failure):
            logger.e("🪵 native migration failed on mnemonic import step: \(failure)")
            completion(.failedMigrateMnemonics(error: failure))
        }
    }

    func performRNMigration(passcode: @escaping (PasscodeFetchHandler) -> Void) async -> MigrationResult {
        logger.i("🪵 starting RN migration flow")
        let mnemonicsMigrationResult = migrateMnemonicsFromRnToNative()
        switch mnemonicsMigrationResult {
        case .success:
            let walletsMigrationResult = await migrateRNWallet()
            switch walletsMigrationResult {
            case let .success(failedWallets):
                switch await migratePasscodeRequiredItemsBiometryPasscode(passcode: passcode) {
                case .success:
                    break
                case let .failure(error):
                    logger.e("🪵 rn migration failed on passcode-required step: \(error)")
                    return .failedMigrateMnemonics(error: error)
                }
                if failedWallets.isEmpty {
                    logger.i("🪵 rn migration completed successfully")
                    return .success
                } else {
                    logger.e("🪵 rn migration partially completed: failedWallets=\(failedWallets.count)")
                    return .partialy(failedWallets: failedWallets)
                }

            case let .failure(error):
                logger.e("🪵 rn migration failed on wallets import step: \(error)")
                return .failedMigrateWallets(error: error)
            }
        case let .failure(failure):
            logger.e("🪵 rn migration failed on mnemonic import step: \(failure)")
            return .failedMigrateMnemonics(error: failure)
        }
    }

    private func migrateMnemonicsFromRnToNative() -> Result<Void, MnemonicMigrationError> {
        let rnMnemonicsRepository: RNMnemonicsVault
        let mnemonicsRepository: MnemonicsVault
        switch mnemonicsAccess {
        case let .v2(_, _, legacyRepository), let .disabled(legacyRepository):
            rnMnemonicsRepository = legacyRepository.rn
            mnemonicsRepository = legacyRepository.native
        }
        guard rnMnemonicsRepository.hasMnemonics() else {
            logger.i("🪵 rn->native mnemonic migration skipped: rn storage is empty")
            return .failure(.noMnemonics)
        }
        let encryptedMnemonics: EncryptedMnemonics
        do {
            encryptedMnemonics = try rnMnemonicsRepository.getEncryptedMnemonics()
            logger.i("🪵 rn->native mnemonic migration: encrypted payload loaded")
        } catch {
            logger.e("🪵 rn->native mnemonic migration failed to read source storage: \(error)")
            return .failure(.readStorageError(error))
        }
        do {
            try mnemonicsRepository.importEncryptedMnemonics(encryptedMnemonics)
            logger.i("🪵 rn->native mnemonic migration: payload imported successfully")
            return .success(())
        } catch {
            logger.e("🪵 rn->native mnemonic migration failed to import payload: \(error)")
            return .failure(.importError(error))
        }
    }

    private func migrateMnemonicsFromNativeToV2(passcode: String) async throws(MnemonicMigrationError) {
        guard case let .v2(v2Repository, passcodeStorage, legacyRepository) = mnemonicsAccess else {
            return
        }

        let mnemonics: Mnemonics
        do {
            mnemonics = try await legacyRepository.native.getMnemonics(password: passcode)
        } catch {
            logger.e("🪵 native->v2 mnemonic migration failed to read legacy storage: \(error)")
            throw .readStorageError(error)
        }

        do {
            try v2Repository.raw.deleteAllKnownStorageArtifacts()
            logger.i("🪵 native->v2 mnemonic migration cleaned previous v2 mnemonic storage artifacts")
        } catch {
            logger.e("🪵 native->v2 mnemonic migration failed to clean previous v2 mnemonic storage artifacts: \(error)")
            throw .importError(error)
        }

        // The biometry-protected passcode cache is recreatable, so a cleanup
        // failure must never fail the mnemonic migration. When biometry is on,
        // the `setPasscode` step below rewrites the cache and already disables
        // biometry if that write fails.
        do {
            try passcodeStorage.deleteAllKnownStorageArtifacts()
            logger.i("🪵 native->v2 mnemonic migration cleaned previous v2 passcode storage artifacts")
        } catch {
            logger.w("🪵 native->v2 mnemonic migration failed to clean previous v2 passcode storage artifacts: \(error)")
        }

        logger.i("🪵 native->v2 mnemonic migration started: totalLegacy=\(mnemonics.count)")
        guard !mnemonics.isEmpty else {
            logger.i("🪵 native->v2 mnemonic migration completed: migrated=0")
            return
        }

        var migratedTon = 0
        var migratedBip39 = 0
        var migratedBip39Soft = 0
        var migratedUnknown = 0
        var expectedV2Mnemonics = [CoreMnemonicIdentifier: CoreMnemonic]()
        let walletsById = walletsByIdForMnemonicMigration()
        for (id, legacyMnemonic) in mnemonics {
            let words = legacyMnemonic.mnemonicWords
            let derivationType = migratedDerivationType(words: words, id: id, walletsById: walletsById)
            let coreMnemonic = CoreMnemonic(
                mnemonicWords: words,
                type: derivationType
            )
            switch derivationType {
            case .ton:
                migratedTon += 1
            case .bip39:
                migratedBip39 += 1
            case .bip39soft:
                migratedBip39Soft += 1
            case .unknown:
                migratedUnknown += 1
            }
            logger.i(
                "🪵 native->v2 mnemonic migration item: id=\(id.redactedMnemonicIdentifier), words=\(words.count), type=\(derivationType.logName)"
            )
            expectedV2Mnemonics[id] = coreMnemonic
        }
        do {
            try v2Repository.raw.rewrite(
                mnemonics: expectedV2Mnemonics,
                passcode: passcode
            )
        } catch {
            logger.e("🪵 native->v2 mnemonic migration failed to write v2 storage: \(error)")
            throw .importError(error)
        }
        logger.i(
            "🪵 native->v2 mnemonic migration completed: migrated=\(mnemonics.count), ton=\(migratedTon), bip39=\(migratedBip39), bip39soft=\(migratedBip39Soft), unknown=\(migratedUnknown)"
        )
    }

    private func walletsByIdForMnemonicMigration() -> [CoreMnemonicIdentifier: Wallet] {
        let wallets: [Wallet]
        do {
            wallets = try keeperInfoRepository.getKeeperInfo().wallets
        } catch {
            logger.w("🪵 native->v2 mnemonic migration failed to read keeper info wallets: \(error)")
            wallets = []
        }
        return wallets.reduce(into: [:]) { result, wallet in
            result[wallet.id] = wallet
        }
    }

    private func migratedDerivationType(
        words: [String],
        id: CoreMnemonicIdentifier,
        walletsById: [CoreMnemonicIdentifier: Wallet]
    ) -> DerivationType {
        guard let wallet = walletsById[id] else {
            logger.w(
                "🪵 native->v2 mnemonic migration found no wallet for id=\(id.redactedMnemonicIdentifier), falling back to guess"
            )
            return .guessByWords(words)
        }
        do {
            return try .resolveByWords(words, publicKey: wallet.publicKey)
        } catch {
            logger.w(
                "🪵 native->v2 mnemonic migration failed to read wallet public key for id=\(id.redactedMnemonicIdentifier), falling back to guess: \(error)"
            )
            return .guessByWords(words)
        }
    }

    private func migratePasscodeRequiredItemsBiometryPasscode(passcode: @escaping (PasscodeFetchHandler) -> Void) async -> Result<Void, MnemonicMigrationError> {
        await withCheckedContinuation { continuation in
            migratePasscodeRequiredItemsBiometryPasscode(passcode: passcode) { result in
                continuation.resume(returning: result)
            }
        }
    }

    private func migratePasscodeRequiredItemsBiometryPasscode(passcode: @escaping (PasscodeFetchHandler) -> Void, completion: @escaping (Result<Void, MnemonicMigrationError>) -> Void) {
        let isBiometryEnable = (try? keeperInfoRepository.getKeeperInfo().securitySettings.isBiometryEnabled) ?? false
        let missedTonProofWallets = tonProofTokenService.getWalletsWithMissedToken()
        let needsMigrateToV2: Bool
        switch v2MigrationState() {
        case .ready:
            needsMigrateToV2 = false
        case .needsMigration:
            needsMigrateToV2 = true
        case let .blocked(error):
            logger.e("🪵 passcode-required migration blocked by v2 committed state read error: \(error)")
            completion(.failure(.readStorageError(error)))
            return
        }
        logger.i(
            "🪵 passcode-required migration check: biometry=\(isBiometryEnable), missedTonProofWallets=\(missedTonProofWallets.count), needsNativeToV2=\(needsMigrateToV2)"
        )

        if isBiometryEnable || !missedTonProofWallets.isEmpty || needsMigrateToV2 {
            let validator: PasscodeInputValidator
            switch mnemonicsAccess {
            case let .v2(_, _, legacyRepository):
                if needsMigrateToV2 {
                    validator = PasscodeLegacyConfirmationValidator(mnemonicsRepository: legacyRepository.native)
                } else {
                    validator = PasscodeConfirmationValidator(mnemonicAccess: mnemonicsAccess)
                }
            case let .disabled(legacyRepository):
                validator = PasscodeLegacyConfirmationValidator(mnemonicsRepository: legacyRepository.native)
            }
            logger.i("🪵 passcode-required migration: waiting for passcode confirmation")
            let onValidPasscode: (String) -> Void = { [mnemonicsAccess] passcode in
                Task { @MainActor in
                    logger.i("🪵 passcode-required migration: passcode accepted")
                    if needsMigrateToV2 {
                        do {
                            try await migrateMnemonicsFromNativeToV2(passcode: passcode)
                        } catch {
                            logger.e("🪵 passcode-required migration failed during native->v2 migration: \(error)")
                            return completion(.failure(.importError(error)))
                        }
                    }
                    if isBiometryEnable {
                        do {
                            try mnemonicsAccess.setPasscode(passcode)
                            logger.i("🪵 passcode-required migration: saved passcode for biometry")
                        } catch {
                            logger.e("🪵 passcode-required migration failed to save passcode for biometry: \(error)")
                            do {
                                try deleteBiometryPasscodeAfterFailedMigration()
                            } catch {
                                logger.e("🪵 passcode-required migration failed to reset passcode storage: \(error)")
                            }
                            _ = await securityStore.setIsBiometryEnable(false)
                            logger.i("🪵 passcode-required migration: disabled biometry after passcode save failure")
                        }
                    }
                    let tonProofMnemonics: [CoreMnemonicIdentifier: CoreMnemonic]
                    do {
                        tonProofMnemonics = try await mnemonicsAccess.getMnemonics(
                            wallets: missedTonProofWallets,
                            passcode: passcode
                        )
                    } catch {
                        logger.e("🪵 passcode-required migration failed to load TonProof mnemonics: \(error)")
                        tonProofMnemonics = [:]
                    }
                    for wallet in missedTonProofWallets {
                        guard let mnemonic = tonProofMnemonics[wallet.id],
                              let keyPair = try? mnemonic.toKeyPair()
                        else {
                            logger.e("🪵 passcode-required migration failed to restore TonProof keys for wallet=\(wallet.id.redactedMnemonicIdentifier)")
                            continue
                        }
                        let pair = WalletPrivateKeyPair(
                            wallet: wallet,
                            privateKey: keyPair.privateKey
                        )
                        await tonProofTokenService.loadTokensFor(pairs: [pair])
                        logger.i("🪵 passcode-required migration refreshed TonProof token for wallet=\(wallet.id.redactedMnemonicIdentifier)")
                    }
                    logger.i("🪵 passcode-required migration completed")
                    completion(.success(()))
                }
            }
            passcode(PasscodeFetchHandler(validator: validator, onSuccess: onValidPasscode))
        } else {
            logger.i("🪵 passcode-required migration skipped")
            completion(.success(()))
        }
    }

    private func deleteBiometryPasscodeAfterFailedMigration() throws {
        switch mnemonicsAccess {
        case let .v2(_, passcodeStorage, _):
            try passcodeStorage.deletePasscode()
        case .disabled:
            try mnemonicsAccess.deletePasscode()
        }
    }

    private func migrateRNWallet() async -> WalletsMigrationResult {
        let rnWalletsStore: RNWalletsStore
        do {
            guard let value: RNWalletsStore = try await asyncStorage.getValue(key: .rnWalletsStoreKey),
                  !value.wallets.isEmpty
            else {
                logger.e("🪵 rn wallet migration failed: wallets store is empty")
                return .failure(error: .noWallets)
            }
            rnWalletsStore = value
        } catch {
            logger.e("🪵 rn wallet migration failed to read wallets store: \(error)")
            return .failure(error: .noWallets)
        }
        logger.i("🪵 rn wallet migration started: total=\(rnWalletsStore.wallets.count)")
        let activeWalletId = rnWalletsStore.selectedIdentifier

        let rnWallets = rnWalletsStore.wallets
        var wallets = [Wallet]()
        var rnWalletNotMigrated = [RNWallet]()
        for rnWallet in rnWalletsStore.wallets {
            let backupDate = try? await getRNWalletBackupDate(walletId: rnWallet.identifier)
            guard let wallet = try? rnWallet.getWallet(backupDate: backupDate) else {
                rnWalletNotMigrated.append(rnWallet)
                logger.e("🪵 rn wallet migration skipped invalid wallet=\(rnWallet.identifier.redactedMnemonicIdentifier)")
                continue
            }
            guard !wallets.contains(where: { $0.identity == wallet.identity }) else { continue }
            wallets.append(wallet)
        }

        guard !wallets.isEmpty else {
            return .failure(error: .failedWalletsMigration(wallet: rnWallets))
        }

        let currentWallet = wallets.first(where: { $0.id == activeWalletId }) ?? wallets[0]
        let isBiometryEnabled = rnWalletsStore.biometryEnabled
        let isLockScreen = rnWalletsStore.lockScreenEnabled
        let currency: Currency = await {
            guard let tonPrice: RNTonPrice = try? await asyncStorage.getValue(key: "ton_price") else {
                return .USD
            }
            let currencyRaw = tonPrice.currency
            return Currency(rawValue: currencyRaw.uppercased()) ?? .USD
        }()

        let keeperInfo = KeeperInfo(
            wallets: wallets,
            currentWallet: currentWallet,
            currency: currency,
            securitySettings: SecuritySettings(
                isBiometryEnabled: isBiometryEnabled,
                isLockScreen: isLockScreen
            ),
            appSettings: KeeperInfo.AppSettings(
                isSecureMode: false,
                searchEngine: .duckduckgo
            ),
            country: .auto
        )

        let theme: TKTheme = await {
            guard let appTheme: RNAppTheme = try? await asyncStorage.getValue(key: .appTheme),
                  let theme = TKTheme(rawValue: appTheme.state.selectedTheme)
            else {
                return .deepBlue
            }
            return theme
        }()
        await MainActor.run {
            TKThemeManager.shared.theme = theme
        }

        do {
            try keeperInfoRepository.saveKeeperInfo(keeperInfo)
            _ = await keeperInfoStore.updateKeeperInfo { _ in
                keeperInfo
            }
            try? await asyncStorage.setValue(value: true, key: "x")
            logger.i(
                "🪵 rn wallet migration completed: migrated=\(wallets.count), failed=\(rnWalletNotMigrated.count), currentWallet=\(currentWallet.id.redactedMnemonicIdentifier)"
            )
            return .success(failedWallets: rnWalletNotMigrated)
        } catch {
            logger.e("🪵 rn wallet migration failed to persist keeper info: \(error)")
            return .failure(error: .importError(error))
        }
    }

    private func getRNWalletBackupDate(walletId: String) async throws -> Date? {
        let key = "\(walletId)/setup"
        guard let setupState: RNWalletSetupState? = try await asyncStorage.getValue(key: key),
              let lastBackupAt = setupState?.lastBackupAt
        else {
            return nil
        }
        return Date(timeIntervalSince1970: lastBackupAt / 1000)
    }
}

private extension String {
    static let rnWalletsStoreKey = "walletsStore"
    static let appTheme = "app-theme"

    var redactedMnemonicIdentifier: String {
        let prefixLength = Swift.min(8, count)
        return String(prefix(prefixLength))
    }
}

private extension DerivationType {
    var logName: String {
        switch self {
        case .ton:
            return "ton"
        case .bip39:
            return "bip39"
        case .bip39soft:
            return "bip39soft"
        case .unknown:
            return "unknown"
        }
    }
}
