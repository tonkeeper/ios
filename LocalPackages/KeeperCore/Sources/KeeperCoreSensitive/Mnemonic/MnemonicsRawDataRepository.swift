import Foundation
import Security
import TKLogging

public struct MnemonicsRawDataRepository {
    private let seedProvider: () -> String
    private let storageSlotResolution: StorageSlotResolution
    private let keychain: any SecureStorageKeychain
    // Production callers always derive at production cost. The test target uses
    // the internal `keychain:` initializer to inject a cheaper Argon2id cost.
    private let argon2Cost: MnemonicsRepositoryV2Crypto.Argon2Cost
    private let logger = LogDomain.mnemonicStorage

    public init(seedProvider: @escaping () -> String) {
        self.init(
            seedProvider: seedProvider,
            storageSlotResolution: .active,
            keychain: SystemSecureStorageKeychain(),
            argon2Cost: .production
        )
    }

    init(
        seedProvider: @escaping () -> String,
        keychain: any SecureStorageKeychain,
        argon2Cost: MnemonicsRepositoryV2Crypto.Argon2Cost = .production
    ) {
        self.init(
            seedProvider: seedProvider,
            storageSlotResolution: .active,
            keychain: keychain,
            argon2Cost: argon2Cost
        )
    }

    private init(
        seedProvider: @escaping () -> String,
        storageSlotResolution: StorageSlotResolution,
        keychain: any SecureStorageKeychain,
        argon2Cost: MnemonicsRepositoryV2Crypto.Argon2Cost
    ) {
        self.seedProvider = seedProvider
        self.storageSlotResolution = storageSlotResolution
        self.keychain = keychain
        self.argon2Cost = argon2Cost
    }
}

private extension MnemonicsRawDataRepository {
    enum StorageSlotResolution {
        case active
        case fixed(ABStorageSlot)
    }
}

public extension MnemonicsRawDataRepository {
    func unlocked(passcode: String) throws(MnemonicsRepositoryV2Failure) -> DefaultMnemonicsRepositoryV2 {
        try resolvedSlotStorage().unlocked(passcode: passcode)
    }

    func rewrite(
        mnemonics: [CoreMnemonicIdentifier: CoreMnemonic],
        passcode: String
    ) throws(MnemonicsRepositoryV2Failure) {
        try commitMnemonicsRewrite(
            mnemonics: mnemonics,
            passcode: passcode,
            stagedCleanupLog: "v2 staged rewrite cleanup failed",
            activationCleanupLog: "v2 staged rewrite activation cleanup failed",
            oldStorageCleanupLog: "v2 old storage cleanup failed after rewrite"
        )
    }

    func changePasscode(
        old: String,
        new: String
    ) throws(MnemonicsRepositoryV2Failure) {
        guard try hasCommittedStorage() else {
            return
        }
        let oldPasscodeRepository = try unlocked(passcode: old)
        let mnemonics = try oldPasscodeRepository.getAll()
        try commitMnemonicsRewrite(
            mnemonics: mnemonics,
            passcode: new,
            stagedCleanupLog: "v2 staged passcode change cleanup failed",
            activationCleanupLog: "v2 staged passcode change activation cleanup failed",
            oldStorageCleanupLog: "v2 old passcode storage cleanup failed after passcode change"
        )
    }

    func deleteAllKnownStorageArtifacts() throws(MnemonicsRepositoryV2Failure) {
        let cleaner = keychainCleaner
        for serviceKey in keychainQueryBuilder.knownStorageServiceKeys {
            try cleaner.deleteStorageArtifacts(serviceKey: serviceKey)
        }
        try encryptionSaltStore.deleteSalt()
    }

    func hasCommittedStorage() throws(MnemonicsRepositoryV2Failure) -> Bool {
        switch try activeStorageSlotState() {
        case .uninitialized:
            false
        case .initialized:
            true
        }
    }
}

extension MnemonicsRawDataRepository: RawMnemonicsDataRepositoryV2 {
    public func hasMnemonic() throws(MnemonicsRepositoryV2Failure) -> Bool {
        let storage: MnemonicsRawDataSlotStorage
        do {
            storage = try resolvedSlotStorage()
        } catch MnemonicsRepositoryV2Failure.notFound {
            return false
        } catch {
            logger.e("Failed to resolve v2 mnemonics storage slot for presence check. error=\(error)")
            throw error
        }
        return try storage.hasMnemonic()
    }

    public func add(
        _ mnemonic: RawMnemonicsData,
        id: CoreMnemonicIdentifier
    ) throws(MnemonicsRepositoryV2Failure) {
        let storage: MnemonicsRawDataSlotStorage
        do {
            storage = try resolvedSlotStorage()
        } catch {
            logger.e("Failed to resolve v2 mnemonics storage slot for add. id=\(id), error=\(error)")
            throw error
        }
        try storage.add(mnemonic, id: id)
    }

    public func upsert(
        _ mnemonic: RawMnemonicsData,
        id: CoreMnemonicIdentifier
    ) throws(MnemonicsRepositoryV2Failure) {
        let storage: MnemonicsRawDataSlotStorage
        do {
            storage = try resolvedSlotStorage()
        } catch {
            logger.e("Failed to resolve v2 mnemonics storage slot for upsert. id=\(id), error=\(error)")
            throw error
        }
        try storage.upsert(mnemonic, id: id)
    }

    public func get(
        id: CoreMnemonicIdentifier
    ) throws(MnemonicsRepositoryV2Failure) -> RawMnemonicsData {
        let storage: MnemonicsRawDataSlotStorage
        do {
            storage = try resolvedSlotStorage()
        } catch {
            logger.e("Failed to resolve v2 mnemonics storage slot for get. id=\(id), error=\(error)")
            throw error
        }
        return try storage.get(id: id)
    }

    public func getAll() throws(MnemonicsRepositoryV2Failure) -> [CoreMnemonicIdentifier: RawMnemonicsData] {
        let storage: MnemonicsRawDataSlotStorage
        do {
            storage = try resolvedSlotStorage()
        } catch {
            logger.e("Failed to resolve v2 mnemonics storage slot for getAll. error=\(error)")
            throw error
        }
        return try storage.getAll()
    }

    public func delete(
        id: CoreMnemonicIdentifier
    ) throws(MnemonicsRepositoryV2Failure) {
        let storage: MnemonicsRawDataSlotStorage
        do {
            storage = try resolvedSlotStorage()
        } catch {
            logger.e("Failed to resolve v2 mnemonics storage slot for delete. id=\(id), error=\(error)")
            throw error
        }
        try storage.delete(id: id)
    }
}

private extension MnemonicsRawDataRepository {
    func commitMnemonicsRewrite(
        mnemonics: [CoreMnemonicIdentifier: CoreMnemonic],
        passcode: String,
        stagedCleanupLog: String,
        activationCleanupLog: String,
        oldStorageCleanupLog: String
    ) throws(MnemonicsRepositoryV2Failure) {
        let input = MnemonicsRawDataSlotStorage.WriteInput(
            mnemonics: mnemonics,
            passcode: passcode
        )
        let commit: ABSlotCommit<MnemonicsRawDataSlotStorage>
        do {
            commit = try abSlotCoordinator.commit(input)
        } catch {
            try handleABSlotCoordinatorFailure(
                error,
                stagedCleanupLog: stagedCleanupLog,
                activationCleanupLog: activationCleanupLog
            )
            throw .storageFailure(underlying: error)
        }

        do {
            try commit.previousStorage?.prepare()
        } catch {
            logger.e("\(oldStorageCleanupLog): \(error)")
        }
    }

    func handleABSlotCoordinatorFailure(
        _ error: ABSlotCoordinatorFailure<MnemonicsRepositoryV2Failure>,
        stagedCleanupLog: String,
        activationCleanupLog: String
    ) throws(MnemonicsRepositoryV2Failure) {
        switch error {
        case let .storage(error):
            throw error
        case let .activeSlot(error):
            throw mnemonicsFailure(from: error)
        case let .stagedDiscardFailed(_, discard):
            logger.e("\(stagedCleanupLog): \(discard)")
            throw .storageFailure(underlying: error)
        case let .activationCleanupFailed(_, discard):
            logger.e("\(activationCleanupLog): \(discard)")
            throw .storageFailure(underlying: error)
        case let .unexpectedStagedSlot(expected, actual):
            logger.e("Unexpected v2 mnemonics staged slot. expected=\(expected), actual=\(actual)")
            throw .securityFailure(code: errSecInternalComponent)
        }
    }
}

private extension MnemonicsRawDataRepository {
    func resolvedSlotStorage() throws(MnemonicsRepositoryV2Failure) -> MnemonicsRawDataSlotStorage {
        try storage(slot: resolvedStorageSlot())
    }

    func resolvedStorageSlot() throws(MnemonicsRepositoryV2Failure) -> ABStorageSlot {
        switch storageSlotResolution {
        case .active:
            return try activeStorageSlot()
        case let .fixed(slot):
            return slot
        }
    }

    func activeStorageSlot() throws(MnemonicsRepositoryV2Failure) -> ABStorageSlot {
        switch try activeStorageSlotState() {
        case .uninitialized:
            throw .notFound
        case let .initialized(slot):
            return slot
        }
    }

    func activeStorageSlotState() throws(MnemonicsRepositoryV2Failure) -> ABActiveSlotState {
        do {
            return try activeSlotStore.activeSlotState()
        } catch {
            switch error {
            case let .unexpectedStatus(status):
                logger.e("Failed to read v2 active mnemonics storage slot. status=\(status)")
                throw .securityFailure(code: status)
            case let .invalidData(value):
                logger.e("Keychain returned malformed v2 active mnemonics storage slot. value=\(value)")
                throw .decodeFailure(message: "invalid active mnemonics storage slot: \(value)")
            }
        }
    }

    func mnemonicsFailure(
        from error: ABActiveSlotKeychainStore.Error
    ) -> MnemonicsRepositoryV2Failure {
        switch error {
        case let .unexpectedStatus(status):
            logger.e("Failed to access v2 active mnemonics storage slot. status=\(status)")
            return .securityFailure(code: status)
        case let .invalidData(value):
            logger.e("Keychain returned malformed v2 active mnemonics storage slot. value=\(value)")
            return .decodeFailure(message: "invalid active mnemonics storage slot: \(value)")
        }
    }

    func storage(slot: ABStorageSlot) -> MnemonicsRawDataSlotStorage {
        let queryBuilder = keychainQueryBuilder
        return MnemonicsRawDataSlotStorage(
            keychain: keychain,
            slot: slot,
            serviceKeys: queryBuilder.storageServiceKeys(slot: slot),
            encryptionSalt: { () throws(MnemonicsRepositoryV2Failure) -> Data in
                try encryptionSaltStore.getSalt()
            },
            keychainQuery: {
                queryBuilder.keychainQuery(for: $0)
            },
            argon2Cost: argon2Cost
        )
    }

    var activeSlotStore: ABActiveSlotKeychainStore {
        ABActiveSlotKeychainStore(
            serviceKey: keychainQueryBuilder.activeStorageServiceKey,
            keychainWriteAccessType: keychainQueryBuilder.keychainWriteAccessType,
            keychain: keychain
        )
    }

    var abSlotCoordinator: ABSlotCoordinator<MnemonicsRawDataSlotStorage> {
        ABSlotCoordinator(
            activeSlotStore: activeSlotStore,
            makeStorage: { storage(slot: $0) }
        )
    }

    var keychainCleaner: MnemonicsRawDataStorageKeychainCleaner {
        let queryBuilder = keychainQueryBuilder
        return MnemonicsRawDataStorageKeychainCleaner(
            keychain: keychain,
            keychainQuery: {
                queryBuilder.keychainQuery(for: $0)
            },
            logger: logger
        )
    }

    var encryptionSaltStore: MnemonicsEncryptionSaltStore {
        MnemonicsEncryptionSaltStore(
            seedProvider: seedProvider,
            keychain: keychain
        )
    }

    var keychainQueryBuilder: MnemonicsRawDataStorageKeychainQueryBuilder {
        MnemonicsRawDataStorageKeychainQueryBuilder(
            seedProvider: seedProvider
        )
    }
}
