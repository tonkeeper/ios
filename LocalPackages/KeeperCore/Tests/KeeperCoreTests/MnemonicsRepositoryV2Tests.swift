import Foundation
@testable import KeeperCore
import KeeperCoreComponents
@testable import KeeperCoreSensitive
import Security
import Testing
import TKKeychain
import TKLogging
import TonSwift

struct MnemonicsRepositoryV2Tests {
    @Test
    func cryptoRoundTripReturnsOriginalMnemonic() throws {
        let original = CoreMnemonic(
            mnemonicWords: ["one", "two", "three"],
            type: .unknown
        )
        let cipher = try makeCipher(
            passcode: "1234"
        )
        let encrypted = try cipher.encrypt(original)

        let decrypted = try cipher.decrypt(encrypted)

        #expect(decrypted == original)
    }

    @Test
    func cryptoRoundTripAtProductionCostReturnsOriginalMnemonic() throws {
        // Every other test derives at the reduced `.testFast` cost, so this is
        // the one case that still exercises the production Argon2id parameters
        // (`MemLimitModerate` / `OpsLimitInteractive`) end to end, guarding
        // against a regression in the production cost configuration.
        let original = CoreMnemonic(
            mnemonicWords: ["one", "two", "three"],
            type: .unknown
        )
        let cipher = try makeCipher(
            passcode: "1234",
            cost: .production
        )
        let encrypted = try cipher.encrypt(original)

        let decrypted = try cipher.decrypt(encrypted)

        #expect(decrypted == original)
    }

    @Test
    func cryptoDecryptFailsWithWrongPasscode() throws {
        let mnemonic = CoreMnemonic(
            mnemonicWords: ["one", "two", "three"],
            type: .unknown
        )
        let salt = try MnemonicsRepositoryV2Crypto.makeSalt()
        let cipher = try makeCipher(
            passcode: "1234",
            salt: salt
        )
        let wrongCipher = try makeCipher(
            passcode: "5678",
            salt: salt
        )
        let encrypted = try cipher.encrypt(mnemonic)

        #expect(throws: (any Error).self) {
            try wrongCipher.decrypt(encrypted)
        }
    }

    @Test
    func cryptoDecryptFailsWithDifferentSalt() throws {
        let mnemonic = CoreMnemonic(
            mnemonicWords: ["one", "two", "three"],
            type: .unknown
        )
        let cipher = try makeCipher(passcode: "1234")
        let wrongCipher = try makeCipher(passcode: "1234")
        let encrypted = try cipher.encrypt(mnemonic)

        #expect(throws: (any Error).self) {
            try wrongCipher.decrypt(encrypted)
        }
    }

    @Test
    func cryptoRejectsInvalidSaltLength() {
        #expect(throws: (any Error).self) {
            _ = try MnemonicsRepositoryV2Crypto.unlock(
                passcode: "1234",
                salt: Data()
            )
        }
    }

    @Test
    func cryptoRawPayloadDoesNotStoreArgonSalt() throws {
        let mnemonic = CoreMnemonic(
            mnemonicWords: ["one", "two", "three"],
            type: .unknown
        )
        let cipher = try makeCipher(passcode: "1234")
        let encrypted = try cipher.encrypt(mnemonic)

        #expect(encrypted.data.first == 2)
        #expect(encrypted.data.count > 1)
    }

    @Test
    func guessByWordsReturnsUnknownForInvalidWords() {
        let guessed = DerivationType.guessByWords(["invalid"])
        #expect(guessed == .unknown)
    }

    @Test
    func guessByWordsReturnsBip39SoftForWordsWithoutChecksum() {
        let words = Array(repeating: "abandon", count: 12)

        #expect(BIP39Mnemonic.isValidBip39SoftMnemonic(mnemonicArray: words))
        #expect(!BIP39Mnemonic.isValidBip39Mnemonic(mnemonicArray: words))
        #expect(DerivationType.guessByWords(words) == .bip39soft)
    }

    @Test
    func guessByWordsReturnsBip39ForValidChecksumMnemonic() {
        let words = [
            "abandon", "abandon", "abandon", "abandon",
            "abandon", "abandon", "abandon", "abandon",
            "abandon", "abandon", "abandon", "about",
        ]

        #expect(BIP39Mnemonic.isValidBip39Mnemonic(mnemonicArray: words))
        #expect(DerivationType.guessByWords(words) == .bip39)
    }

    @Test
    func guessByWordsReturnsTonForValidTonMnemonic() {
        let tonWords = TonSwift.Mnemonic.mnemonicNew()

        #expect(TonSwift.Mnemonic.mnemonicValidate(mnemonicArray: tonWords))
        #expect(DerivationType.guessByWords(tonWords) == .ton)
    }

    @Test
    func isAmbiguousReturnsTrueForValidTonAndBip39Mnemonic() {
        // A phrase that passes both the TON basic-seed check and the BIP39
        // checksum, so `isAmbiguous` is true and `guessByWords` resolves to TON.
        let words = [
            "business", "thunder", "episode", "arena",
            "tray", "twelve", "humble", "asthma",
            "uphold", "pumpkin", "crunch", "fortune",
        ]

        #expect(TonSwift.Mnemonic.mnemonicValidate(mnemonicArray: words))
        #expect(BIP39Mnemonic.isValidBip39Mnemonic(mnemonicArray: words))
        #expect(DerivationType.isAmbiguous(words))
        #expect(DerivationType.guessByWords(words) == .ton)
    }

    @Test
    func isAmbiguousReturnsFalseForTonOnlyMnemonic() {
        let tonWords = TonSwift.Mnemonic.mnemonicNew()
        #expect(!DerivationType.isAmbiguous(tonWords))
    }

    @Test
    func resolveByWordsPicksDerivationMatchingPublicKey() throws {
        let words = [
            "business", "thunder", "episode", "arena",
            "tray", "twelve", "humble", "asthma",
            "uphold", "pumpkin", "crunch", "fortune",
        ]
        let tonPublicKey = try TonSwift.Mnemonic.mnemonicToPrivateKey(mnemonicArray: words).publicKey
        let bip39PublicKey = try BIP39Mnemonic.bip39MnemonicToKeyPair(mnemonicArray: words).publicKey

        #expect(DerivationType.resolveByWords(words, publicKey: tonPublicKey) == .ton)
        #expect(DerivationType.resolveByWords(words, publicKey: bip39PublicKey) == .bip39)
    }

    @Test
    func resolveByWordsFallsBackToGuessForUnmatchedPublicKey() {
        let words = [
            "business", "thunder", "episode", "arena",
            "tray", "twelve", "humble", "asthma",
            "uphold", "pumpkin", "crunch", "fortune",
        ]
        let unrelatedPublicKey = TonSwift.PublicKey(data: Data(repeating: 7, count: 32))

        #expect(DerivationType.resolveByWords(words, publicKey: unrelatedPublicKey) == .ton)
    }

    @Test
    func resolveByWordsIgnoresPublicKeyForNonAmbiguousMnemonic() {
        let words = [
            "abandon", "abandon", "abandon", "abandon",
            "abandon", "abandon", "abandon", "abandon",
            "abandon", "abandon", "abandon", "about",
        ]
        let tonStylePublicKey = TonSwift.PublicKey(data: Data(repeating: 7, count: 32))

        #expect(!DerivationType.isAmbiguous(words))
        #expect(DerivationType.resolveByWords(words, publicKey: tonStylePublicKey) == .bip39)
    }

    @Test
    func shouldOfferWalletKindSelectionReturnsFalseForBip39SoftMnemonic() {
        let words = Array(repeating: "abandon", count: 12)
        #expect(!DerivationType.shouldOfferWalletKindSelection(words))
    }

    @Test
    func shouldOfferWalletKindSelectionReturnsTrueForAmbiguousMnemonic() {
        let words = [
            "business", "thunder", "episode", "arena",
            "tray", "twelve", "humble", "asthma",
            "uphold", "pumpkin", "crunch", "fortune",
        ]

        #expect(DerivationType.shouldOfferWalletKindSelection(words))
    }

    @Test
    func shouldOfferWalletKindSelectionReturnsFalseForBip39OnlyMnemonic() {
        let words = [
            "abandon", "abandon", "abandon", "abandon",
            "abandon", "abandon", "abandon", "abandon",
            "abandon", "abandon", "abandon", "about",
        ]

        #expect(BIP39Mnemonic.isValidBip39Mnemonic(mnemonicArray: words))
        #expect(!TonSwift.Mnemonic.mnemonicValidate(mnemonicArray: words))
        #expect(!DerivationType.shouldOfferWalletKindSelection(words))
    }

    @Test
    func shouldOfferWalletKindSelectionReturnsFalseForTonOnlyMnemonic() {
        let tonWords = TonSwift.Mnemonic.mnemonicNew()
        #expect(!DerivationType.shouldOfferWalletKindSelection(tonWords))
    }

    @Test
    func toKeyPairSupportsBip39SoftMnemonic() throws {
        let mnemonic = CoreMnemonic(
            mnemonicWords: Array(repeating: "abandon", count: 12),
            type: .bip39soft
        )

        _ = try mnemonic.toKeyPair()
    }

    @Test
    func toKeyPairForBip39AndBip39SoftProducesSameKeyPair() throws {
        let words = Array(repeating: "abandon", count: 12)
        let bip39 = CoreMnemonic(
            mnemonicWords: words,
            type: .bip39
        )
        let bip39soft = CoreMnemonic(
            mnemonicWords: words,
            type: .bip39soft
        )

        let bip39KeyPair = try bip39.toKeyPair()
        let bip39softKeyPair = try bip39soft.toKeyPair()

        #expect(bip39KeyPair.publicKey.data == bip39softKeyPair.publicKey.data)
        #expect(bip39KeyPair.privateKey.data == bip39softKeyPair.privateKey.data)
    }

    @Test
    func cryptoRoundTripPreservesUnknownTypeAndInvalidWords() throws {
        let mnemonic = CoreMnemonic(
            mnemonicWords: ["this", "is", "not", "a", "valid", "mnemonic"],
            type: .unknown
        )
        let cipher = try makeCipher(passcode: "1234")
        let encrypted = try cipher.encrypt(mnemonic)

        let restored = try cipher.decrypt(encrypted)
        #expect(restored == mnemonic)
    }

    @Test
    func repositoryPersistsUnknownMnemonicWithoutValidation() throws {
        let mnemonic = CoreMnemonic(
            mnemonicWords: ["this", "is", "not", "a", "valid", "mnemonic"],
            type: .unknown
        )
        let repository = try makeRepository(
            passcode: "1234",
            rawStorage: InMemoryRawMnemonicsStorage()
        )

        try repository.upsert(mnemonic, id: "wallet_unknown")

        let restored = try repository.get(id: "wallet_unknown")
        #expect(restored == mnemonic)
    }

    @Test
    func repositoryStoresEachMnemonicBySeparateId() throws {
        let repository = try makeRepository(
            passcode: "1234",
            rawStorage: InMemoryRawMnemonicsStorage()
        )
        let firstMnemonic = CoreMnemonic(
            mnemonicWords: Array(repeating: "abandon", count: 12),
            type: .bip39soft
        )
        let secondMnemonic = CoreMnemonic(
            mnemonicWords: ["custom", "words", "are", "kept", "as", "is"],
            type: .unknown
        )

        try repository.add(firstMnemonic, id: "wallet_1")
        try repository.add(secondMnemonic, id: "wallet_2")
        try repository.delete(id: "wallet_1")

        #expect(throws: MnemonicsRepositoryV2Failure.self) {
            _ = try repository.get(id: "wallet_1")
        }
        let restoredSecond = try repository.get(id: "wallet_2")
        #expect(restoredSecond == secondMnemonic)
    }

    @Test
    func repositoryGetAllPreservesDerivationTypeForMigratedMnemonics() throws {
        let repository = try makeRepository(
            passcode: "1234",
            rawStorage: InMemoryRawMnemonicsStorage()
        )

        let tonWords = TonSwift.Mnemonic.mnemonicNew()
        let tonMnemonic = CoreMnemonic(mnemonicWords: tonWords, type: .ton)
        let bip39Mnemonic = CoreMnemonic(
            mnemonicWords: [
                "abandon", "abandon", "abandon", "abandon",
                "abandon", "abandon", "abandon", "abandon",
                "abandon", "abandon", "abandon", "about",
            ],
            type: .bip39
        )
        let bip39SoftMnemonic = CoreMnemonic(
            mnemonicWords: Array(repeating: "abandon", count: 12),
            type: .bip39soft
        )
        let unknownMnemonic = CoreMnemonic(
            mnemonicWords: ["custom", "words", "that", "stay", "as", "is"],
            type: .unknown
        )

        try repository.upsert(tonMnemonic, id: "wallet_ton")
        try repository.upsert(bip39Mnemonic, id: "wallet_bip39")
        try repository.upsert(bip39SoftMnemonic, id: "wallet_bip39soft")
        try repository.upsert(unknownMnemonic, id: "wallet_unknown")

        let restored = try repository.getAll()

        #expect(restored.count == 4)
        #expect(restored["wallet_ton"] == tonMnemonic)
        #expect(restored["wallet_bip39"] == bip39Mnemonic)
        #expect(restored["wallet_bip39soft"] == bip39SoftMnemonic)
        #expect(restored["wallet_unknown"] == unknownMnemonic)
    }

    @Test
    func repositoryUpsertOverwritesMnemonicForSameId() throws {
        let repository = try makeRepository(
            passcode: "1234",
            rawStorage: InMemoryRawMnemonicsStorage()
        )

        let initial = CoreMnemonic(
            mnemonicWords: ["old", "value"],
            type: .unknown
        )
        let updated = CoreMnemonic(
            mnemonicWords: Array(repeating: "abandon", count: 12),
            type: .bip39soft
        )

        try repository.upsert(initial, id: "wallet")
        try repository.upsert(updated, id: "wallet")

        let restored = try repository.get(id: "wallet")
        #expect(restored == updated)
    }

    @Test
    func repositoryGetRejectsWrongPasscode() throws {
        let salt = try MnemonicsRepositoryV2Crypto.makeSalt()
        let rawStorage = InMemoryRawMnemonicsStorage()
        let correctRepository = try makeRepository(
            passcode: "1234",
            salt: salt,
            rawStorage: rawStorage
        )
        let wrongRepository = try makeRepository(
            passcode: "9999",
            salt: salt,
            rawStorage: rawStorage
        )
        let initial = CoreMnemonic(
            mnemonicWords: ["existing", "mnemonic"],
            type: .unknown
        )
        try correctRepository.upsert(initial, id: "wallet")

        #expect(throws: (any Error).self) {
            _ = try wrongRepository.get(id: "wallet")
        }
    }

    @Test
    func repositoryGetAllRejectsWrongPasscode() throws {
        let salt = try MnemonicsRepositoryV2Crypto.makeSalt()
        let rawStorage = InMemoryRawMnemonicsStorage()
        let correctRepository = try makeRepository(
            passcode: "1234",
            salt: salt,
            rawStorage: rawStorage
        )
        let wrongRepository = try makeRepository(
            passcode: "9999",
            salt: salt,
            rawStorage: rawStorage
        )
        let first = CoreMnemonic(
            mnemonicWords: ["first", "mnemonic"],
            type: .unknown
        )
        let second = CoreMnemonic(
            mnemonicWords: ["second", "mnemonic"],
            type: .unknown
        )
        try correctRepository.upsert(first, id: "wallet_1")
        try correctRepository.upsert(second, id: "wallet_2")

        #expect(throws: (any Error).self) {
            _ = try wrongRepository.getAll()
        }
    }

    @Test
    func rawStorageRewriteReplacesActiveStorage() throws {
        let rawStorage = makeRawStorage(keychain: InMemorySecureStorageKeychain())
        defer {
            try? rawStorage.deleteAllKnownStorageArtifacts()
        }
        let oldMnemonic = CoreMnemonic(
            mnemonicWords: ["old", "active", "mnemonic"],
            type: .unknown
        )
        let newMnemonic = CoreMnemonic(
            mnemonicWords: ["new", "staged", "mnemonic"],
            type: .unknown
        )
        try rawStorage.rewrite(mnemonics: ["wallet": oldMnemonic], passcode: "old")

        try rawStorage.rewrite(mnemonics: ["wallet": newMnemonic], passcode: "new")

        #expect(try rawStorage.unlocked(passcode: "new").getAll() == ["wallet": newMnemonic])
        #expect(throws: MnemonicsRepositoryV2Failure.self) {
            _ = try rawStorage.unlocked(passcode: "old").getAll()
        }
        #expect(try rawStorage.hasCommittedStorage())
    }

    @Test
    func unlockedRepositoryKeepsPinnedSlotAfterActiveSlotSwap() throws {
        let rawStorage = makeRawStorage(keychain: InMemorySecureStorageKeychain())
        defer {
            try? rawStorage.deleteAllKnownStorageArtifacts()
        }
        let oldMnemonic = CoreMnemonic(
            mnemonicWords: ["old", "active", "mnemonic"],
            type: .unknown
        )
        let newMnemonic = CoreMnemonic(
            mnemonicWords: ["new", "active", "mnemonic"],
            type: .unknown
        )
        let staleMnemonic = CoreMnemonic(
            mnemonicWords: ["stale", "old", "repository"],
            type: .unknown
        )
        try rawStorage.rewrite(mnemonics: ["wallet": oldMnemonic], passcode: "old")
        let oldRepository = try rawStorage.unlocked(passcode: "old")
        try rewriteMnemonicSet(
            rawStorage: rawStorage,
            passcode: "new",
            mnemonic: newMnemonic
        )

        try oldRepository.upsert(staleMnemonic, id: "stale_wallet")

        #expect(try rawStorage.unlocked(passcode: "new").getAll() == ["wallet": newMnemonic])
        #expect(throws: MnemonicsRepositoryV2Failure.self) {
            _ = try rawStorage.unlocked(passcode: "old").getAll()
        }
        #expect(try rawStorage.hasCommittedStorage())
    }

    @Test
    func rawStorageRewriteFailureKeepsActiveSlotReadable() throws {
        let seed = "mnemonics-v2-tests-\(UUID().uuidString)"
        let keychain = InMemorySecureStorageKeychain()
        let rawStorage = makeRawStorage(seed: seed, keychain: keychain)
        defer {
            try? rawStorage.deleteAllKnownStorageArtifacts()
        }
        let oldMnemonic = CoreMnemonic(
            mnemonicWords: ["old", "active", "mnemonic"],
            type: .unknown
        )
        let stagedMnemonic = CoreMnemonic(
            mnemonicWords: ["partially", "written", "mnemonic"],
            type: .unknown
        )
        try rawStorage.rewrite(mnemonics: ["wallet": oldMnemonic], passcode: "old")

        keychain.setAddFailure(
            service: "v2mnemonics_b_\(seed)",
            account: "wallet",
            status: errSecInteractionNotAllowed
        )

        do {
            try rawStorage.rewrite(mnemonics: ["wallet": stagedMnemonic], passcode: "new")
            Issue.record("Expected staged rewrite failure")
        } catch let MnemonicsRepositoryV2Failure.securityFailure(code) {
            #expect(code == errSecInteractionNotAllowed)
        } catch {
            Issue.record("Expected staged rewrite failure, got \(error)")
        }

        #expect(try rawStorage.unlocked(passcode: "old").getAll() == ["wallet": oldMnemonic])
        #expect(throws: MnemonicsRepositoryV2Failure.self) {
            _ = try rawStorage.unlocked(passcode: "new").getAll()
        }
        #expect(keychain.containsItem(service: saltServiceKey(seed: seed), account: "argon2_salt"))
    }

    @Test
    func rawStorageUsesSingleSaltAcrossRewrites() throws {
        let seed = "mnemonics-v2-tests-\(UUID().uuidString)"
        let keychain = InMemorySecureStorageKeychain()
        let rawStorage = makeRawStorage(seed: seed, keychain: keychain)
        let saltStore = makeSaltStore(seed: seed, keychain: keychain)
        defer {
            try? rawStorage.deleteAllKnownStorageArtifacts()
        }
        let firstMnemonic = CoreMnemonic(
            mnemonicWords: ["first", "active", "mnemonic"],
            type: .unknown
        )
        let secondMnemonic = CoreMnemonic(
            mnemonicWords: ["second", "active", "mnemonic"],
            type: .unknown
        )

        try rawStorage.rewrite(mnemonics: ["wallet": firstMnemonic], passcode: "first")
        let firstSalt = try saltStore.getSalt()

        try rawStorage.rewrite(mnemonics: ["wallet": secondMnemonic], passcode: "second")

        #expect(try saltStore.getSalt() == firstSalt)
        #expect(try rawStorage.unlocked(passcode: "second").getAll() == ["wallet": secondMnemonic])
        #expect(throws: MnemonicsRepositoryV2Failure.self) {
            _ = try rawStorage.unlocked(passcode: "first").getAll()
        }
    }

    @Test
    func rawStorageChangePasscodeDoesNotRotateSalt() throws {
        let seed = "mnemonics-v2-tests-\(UUID().uuidString)"
        let keychain = InMemorySecureStorageKeychain()
        let rawStorage = makeRawStorage(seed: seed, keychain: keychain)
        let saltStore = makeSaltStore(seed: seed, keychain: keychain)
        defer {
            try? rawStorage.deleteAllKnownStorageArtifacts()
        }
        let mnemonic = CoreMnemonic(
            mnemonicWords: ["old", "active", "mnemonic"],
            type: .unknown
        )
        try rawStorage.rewrite(mnemonics: ["wallet": mnemonic], passcode: "old")
        let firstSalt = try saltStore.getSalt()

        try rawStorage.changePasscode(old: "old", new: "new")

        #expect(try saltStore.getSalt() == firstSalt)
        #expect(try rawStorage.unlocked(passcode: "new").getAll() == ["wallet": mnemonic])
    }

    @Test
    func rawStorageCanSwapSlotsRepeatedly() throws {
        let rawStorage = makeRawStorage(keychain: InMemorySecureStorageKeychain())
        defer {
            try? rawStorage.deleteAllKnownStorageArtifacts()
        }
        let firstMnemonic = CoreMnemonic(
            mnemonicWords: ["first", "active", "mnemonic"],
            type: .unknown
        )
        let secondMnemonic = CoreMnemonic(
            mnemonicWords: ["second", "active", "mnemonic"],
            type: .unknown
        )
        let thirdMnemonic = CoreMnemonic(
            mnemonicWords: ["third", "active", "mnemonic"],
            type: .unknown
        )
        try rawStorage.rewrite(mnemonics: ["wallet": firstMnemonic], passcode: "first")

        try rewriteMnemonicSet(
            rawStorage: rawStorage,
            passcode: "second",
            mnemonic: secondMnemonic
        )

        #expect(try rawStorage.unlocked(passcode: "second").getAll() == ["wallet": secondMnemonic])

        try rawStorage.rewrite(
            mnemonics: ["wallet": thirdMnemonic],
            passcode: "third"
        )

        #expect(try rawStorage.unlocked(passcode: "third").getAll() == ["wallet": thirdMnemonic])
        #expect(throws: MnemonicsRepositoryV2Failure.self) {
            _ = try rawStorage.unlocked(passcode: "second").getAll()
        }
    }

    @Test
    func rawStorageChangePasscodeRewritesStorageWithNewPasscode() throws {
        let rawStorage = makeRawStorage(keychain: InMemorySecureStorageKeychain())
        defer {
            try? rawStorage.deleteAllKnownStorageArtifacts()
        }
        let mnemonic = CoreMnemonic(
            mnemonicWords: ["old", "active", "mnemonic"],
            type: .unknown
        )
        try rawStorage.rewrite(mnemonics: ["wallet": mnemonic], passcode: "old")

        try rawStorage.changePasscode(old: "old", new: "new")

        #expect(try rawStorage.unlocked(passcode: "new").getAll() == ["wallet": mnemonic])
        #expect(throws: MnemonicsRepositoryV2Failure.self) {
            _ = try rawStorage.unlocked(passcode: "old").getAll()
        }
        #expect(try rawStorage.hasCommittedStorage())
    }

    @Test
    func rawStorageCommittedStateTracksActiveSlotPointer() throws {
        let rawStorage = makeRawStorage(keychain: InMemorySecureStorageKeychain())
        defer {
            try? rawStorage.deleteAllKnownStorageArtifacts()
        }
        let mnemonic = CoreMnemonic(
            mnemonicWords: ["committed", "mnemonic"],
            type: .unknown
        )

        #expect(try rawStorage.hasCommittedStorage() == false)

        try rawStorage.rewrite(
            mnemonics: ["wallet": mnemonic],
            passcode: "1234"
        )

        #expect(try rawStorage.hasCommittedStorage())
    }

    @Test
    func rawStorageRewriteEmptyCommitsEmptyActiveStorage() throws {
        let seed = "mnemonics-v2-tests-\(UUID().uuidString)"
        let keychain = InMemorySecureStorageKeychain()
        let rawStorage = makeRawStorage(seed: seed, keychain: keychain)
        defer {
            try? rawStorage.deleteAllKnownStorageArtifacts()
        }
        let mnemonic = CoreMnemonic(
            mnemonicWords: ["committed", "mnemonic"],
            type: .unknown
        )
        try rawStorage.rewrite(
            mnemonics: ["wallet": mnemonic],
            passcode: "1234"
        )

        try rawStorage.rewrite(mnemonics: [:], passcode: "1234")

        #expect(try rawStorage.hasCommittedStorage())
        #expect(try rawStorage.hasMnemonic() == false)
        #expect(keychain.containsItem(service: "v2mnemonics_active_slot_\(seed)", account: "active_slot"))
        #expect(try rawStorage.unlocked(passcode: "any-password").getAll() == [:])
    }

    @Test
    func v2SaveMnemonicAfterEmptyStateWritesMnemonic() async throws {
        let seed = "mnemonics-v2-tests-\(UUID().uuidString)"
        let rawStorage = makeRawStorage(
            seed: seed,
            keychain: InMemorySecureStorageKeychain()
        )
        defer {
            try? rawStorage.deleteAllKnownStorageArtifacts()
        }
        let mnemonicAccess = makeV2MnemonicAccess(
            rawStorage: rawStorage,
            seed: seed
        )
        let wallet = makeWallet(id: "wallet")
        let mnemonic = CoreMnemonic(
            mnemonicWords: TonSwift.Mnemonic.mnemonicNew(),
            type: .ton
        )
        try rawStorage.rewrite(mnemonics: [:], passcode: "1234")
        #expect(try rawStorage.hasCommittedStorage())

        try await mnemonicAccess.saveMnemonic(mnemonic, wallet: wallet, passcode: "1234")

        #expect(try rawStorage.hasCommittedStorage())
        #expect(try rawStorage.hasMnemonic())
        #expect(try rawStorage.unlocked(passcode: "1234").getAll() == [wallet.id: mnemonic])
    }

    @Test
    func v2BatchGetMnemonicsUnlocksStorageOnce() async throws {
        let seed = "mnemonics-v2-tests-\(UUID().uuidString)"
        let rawStorage = makeRawStorage(
            seed: seed,
            keychain: InMemorySecureStorageKeychain()
        )
        defer {
            try? rawStorage.deleteAllKnownStorageArtifacts()
        }
        let firstWallet = makeWallet(id: "first_wallet")
        let secondWallet = makeWallet(id: "second_wallet")
        let missingWallet = makeWallet(id: "missing_wallet")
        let firstMnemonic = CoreMnemonic(
            mnemonicWords: TonSwift.Mnemonic.mnemonicNew(),
            type: .ton
        )
        let secondMnemonic = CoreMnemonic(
            mnemonicWords: Array(repeating: "abandon", count: 12),
            type: .bip39soft
        )
        try rawStorage.rewrite(
            mnemonics: [
                firstWallet.id: firstMnemonic,
                secondWallet.id: secondMnemonic,
            ],
            passcode: "1234"
        )
        let unlockCounter = Counter()
        let mnemonicAccess = MnemonicAccess.v2(
            mnemonicsRepository: MnemonicAccess.ModernRepository(
                raw: rawStorage,
                unlocked: { passcode in
                    unlockCounter.increment()
                    return try rawStorage.unlocked(passcode: passcode)
                }
            ),
            passcodeStorage: PasscodeStorage(
                seedProvider: { seed },
                keychain: InMemorySecureStorageKeychain()
            ),
            legacyRepository: makeUnusedLegacyRepository(seed: seed)
        )

        let result = try await mnemonicAccess.getMnemonics(
            wallets: [firstWallet, secondWallet, missingWallet],
            passcode: "1234"
        )

        #expect(unlockCounter.value == 1)
        #expect(result == [
            firstWallet.id: firstMnemonic,
            secondWallet.id: secondMnemonic,
        ])
    }

    @Test
    func rawStorageBareActiveSlotIsCommittedStorage() throws {
        let seed = "mnemonics-v2-tests-\(UUID().uuidString)"
        let keychain = InMemorySecureStorageKeychain()
        let rawStorage = makeRawStorage(seed: seed, keychain: keychain)
        defer {
            try? rawStorage.deleteAllKnownStorageArtifacts()
        }
        keychain.setItem(
            service: "v2mnemonics_active_slot_\(seed)",
            account: "active_slot",
            data: Data("a".utf8)
        )

        #expect(try rawStorage.hasCommittedStorage())
        #expect(try rawStorage.hasMnemonic() == false)

        try rawStorage.deleteAllKnownStorageArtifacts()

        #expect(!keychain.containsItem(service: "v2mnemonics_active_slot_\(seed)", account: "active_slot"))
    }

    @Test
    func rawStorageCommittedStateDoesNotRequireSalt() throws {
        let seed = "mnemonics-v2-tests-\(UUID().uuidString)"
        let keychain = InMemorySecureStorageKeychain()
        let rawStorage = makeRawStorage(seed: seed, keychain: keychain)
        defer {
            try? rawStorage.deleteAllKnownStorageArtifacts()
        }
        keychain.setItem(
            service: "v2mnemonics_active_slot_\(seed)",
            account: "active_slot",
            data: Data("a".utf8)
        )
        try keychain.setItem(
            service: "v2mnemonics_\(seed)",
            account: "wallet",
            data: JSONEncoder().encode(RawMnemonicsData(data: Data([2, 1, 2, 3])))
        )

        #expect(try rawStorage.hasCommittedStorage())
        #expect(throws: MnemonicsRepositoryV2Failure.self) {
            _ = try rawStorage.unlocked(passcode: "1234").getAll()
        }
    }

    @Test
    func rawStorageDeleteAllKnownStorageArtifactsRemovesLegacyReadinessMarker() throws {
        let seed = "mnemonics-v2-tests-\(UUID().uuidString)"
        let keychain = InMemorySecureStorageKeychain()
        let rawStorage = makeRawStorage(seed: seed, keychain: keychain)
        let legacyReadinessMarkerService = "v2mnemonics_marker_\(seed)"
        keychain.setItem(
            service: legacyReadinessMarkerService,
            account: "readiness",
            data: Data("legacy-marker".utf8)
        )

        try rawStorage.deleteAllKnownStorageArtifacts()

        #expect(!keychain.containsItem(service: legacyReadinessMarkerService, account: "readiness"))
    }

    @Test
    func rawStorageDeleteAllKnownStorageArtifactsRemovesGlobalAndLegacySalts() throws {
        let seed = "mnemonics-v2-tests-\(UUID().uuidString)"
        let keychain = InMemorySecureStorageKeychain()
        let rawStorage = makeRawStorage(seed: seed, keychain: keychain)
        let saltStore = makeSaltStore(seed: seed, keychain: keychain)
        _ = try saltStore.getSalt()
        keychain.setItem(
            service: "v2mnemonics_params_\(seed)",
            account: "argon2_salt",
            data: Data(repeating: 1, count: MnemonicsRepositoryV2Crypto.saltLength)
        )
        keychain.setItem(
            service: "v2mnemonics_b_params_\(seed)",
            account: "argon2_salt",
            data: Data(repeating: 2, count: MnemonicsRepositoryV2Crypto.saltLength)
        )

        try rawStorage.deleteAllKnownStorageArtifacts()

        for service in [
            saltServiceKey(seed: seed),
            "v2mnemonics_params_\(seed)",
            "v2mnemonics_b_params_\(seed)",
        ] {
            #expect(!keychain.containsItem(service: service, account: "argon2_salt"))
        }
    }

    @Test
    func v2SetPasscodeRemovesLegacyPasscodeForFeatureFlagRollback() throws {
        let seed = "mnemonics-v2-tests-\(UUID().uuidString)"
        let rawStorage = makeRawStorage(
            seed: seed,
            keychain: InMemorySecureStorageKeychain()
        )
        let legacyRepository = makeLegacyRepository(
            seed: seed,
            keychainVault: InMemoryPasswordKeychainVault()
        )
        let passcodeStorage = PasscodeStorage(
            seedProvider: { seed },
            keychain: InMemorySecureStorageKeychain()
        )
        let mnemonicAccess = MnemonicAccess.v2(
            mnemonicsRepository: MnemonicAccess.ModernRepository(
                raw: rawStorage,
                unlocked: { passcode in
                    try rawStorage.unlocked(passcode: passcode)
                }
            ),
            passcodeStorage: passcodeStorage,
            legacyRepository: legacyRepository
        )
        try legacyRepository.native.savePassword("legacy")
        #expect(legacyRepository.native.hasPassword())

        try mnemonicAccess.setPasscode("1234")

        #expect(try mnemonicAccess.getPasscode() == "1234")
        #expect(!legacyRepository.native.hasPassword())
        let rollbackMnemonicAccess = MnemonicAccess.disabled(
            mnemonicsRepository: legacyRepository
        )
        #expect(throws: TKKeychainError.self) {
            _ = try rollbackMnemonicAccess.getPasscode()
        }
    }

    @Test
    func legacySavePasswordOverwritesExistingPassword() throws {
        let seed = "mnemonics-v2-tests-\(UUID().uuidString)"
        let legacyRepository = makeLegacyRepository(
            seed: seed,
            keychainVault: InMemoryPasswordKeychainVault()
        )

        try legacyRepository.native.savePassword("first")
        try legacyRepository.native.savePassword("second")

        #expect(try legacyRepository.native.getPassword() == "second")
        #expect(legacyRepository.native.hasPassword())
    }

    @Test
    func legacySavePasswordSurfacesWriteFailure() throws {
        let seed = "mnemonics-v2-tests-\(UUID().uuidString)"
        let vault = InMemoryPasswordKeychainVault()
        let legacyRepository = makeLegacyRepository(seed: seed, keychainVault: vault)

        try legacyRepository.native.savePassword("first")
        // A single keychain item can't be replaced transactionally; if the write
        // fails after the delete, the error must surface so the caller can retry
        // (the next passcode entry re-saves the value) instead of silently
        // proceeding as if biometry were still set up.
        vault.failNextSet(times: 1)
        #expect(throws: (any Error).self) {
            try legacyRepository.native.savePassword("second")
        }
    }

    @Test
    func legacyBiometryMigrationMarkerLifecycle() throws {
        let seed = "mnemonics-v2-tests-\(UUID().uuidString)"
        let native = makeLegacyRepository(
            seed: seed,
            keychainVault: InMemoryPasswordKeychainVault()
        ).native

        // A legacy biometryAny item has no marker yet → needs migration.
        #expect(!native.isBiometryItemMigrated())

        // savePassword re-creates the item with biometryCurrentSet and records it.
        try native.savePassword("secret")
        #expect(native.isBiometryItemMigrated())

        // Deleting the password clears the marker too.
        try native.deletePassword()
        #expect(!native.isBiometryItemMigrated())
    }

    @Test
    func disabledBiometryProbeReclassifiesMissingItemWithMarkerAsInvalidated() throws {
        // Core device-recovery rule: an invalidated biometryCurrentSet item reads
        // as not-found (.missing) on device. The marker survives the enrollment
        // change and proves the cache existed, so this is invalidated, not absent.
        let seed = "mnemonics-v2-tests-\(UUID().uuidString)"
        let keychainVault = InMemoryPasswordKeychainVault()
        let legacy = makeLegacyRepository(seed: seed, keychainVault: keychainVault)
        let access = MnemonicAccess.disabled(mnemonicsRepository: legacy)

        try legacy.native.importEncryptedMnemonics(makeEncryptedMnemonics())
        try legacy.native.savePassword("secret")
        keychainVault.removeItem(service: "password_vault_\(seed)", account: "biometry_passcode")

        #expect(access.biometryAccessProbe() == .invalidated)
        #expect(!access.isBiometryCacheDiscarded())
    }

    @Test
    func disabledBiometryProbeKeepsDiscardedCacheAsMissingDespiteMnemonics() throws {
        // Storage-v2 rollback shape: the cache AND its marker are gone, so nothing
        // about the enrolled set changed. Reporting .invalidated here is what
        // raised a bogus "biometry changed" notice after a rollback (TK-2375).
        let seed = "mnemonics-v2-tests-\(UUID().uuidString)"
        let legacy = makeLegacyRepository(seed: seed, keychainVault: InMemoryPasswordKeychainVault())
        let access = MnemonicAccess.disabled(mnemonicsRepository: legacy)

        try legacy.native.importEncryptedMnemonics(makeEncryptedMnemonics())
        try legacy.native.savePassword("secret")
        // What migrating to v2 does to the legacy cache, and what a rollback then
        // leaves behind: the password item and its marker are both gone.
        try legacy.native.deletePassword()

        #expect(access.biometryAccessProbe() == .missing)
        #expect(access.isBiometryCacheDiscarded())
    }

    @Test
    func biometryCacheIsNotReportedDiscardedWhileTheLegacyCacheAwaitsV2Migration() throws {
        // Storage v2 is enabled but its passcode storage is still empty, because
        // the native->v2 migration has not run yet. The live legacy cache is about
        // to be migrated into it, so biometry must NOT be treated as discarded —
        // doing so disables biometry for every migrating user.
        let seed = "mnemonics-v2-tests-\(UUID().uuidString)"
        let legacyRepository = makeLegacyRepository(
            seed: seed,
            keychainVault: InMemoryPasswordKeychainVault()
        )
        let rawStorage = makeRawStorage(seed: seed, keychain: InMemorySecureStorageKeychain())
        let access = MnemonicAccess.v2(
            mnemonicsRepository: MnemonicAccess.ModernRepository(
                raw: rawStorage,
                unlocked: { passcode in
                    try rawStorage.unlocked(passcode: passcode)
                }
            ),
            passcodeStorage: PasscodeStorage(
                seedProvider: { seed },
                keychain: InMemorySecureStorageKeychain()
            ),
            legacyRepository: legacyRepository
        )

        try legacyRepository.native.importEncryptedMnemonics(makeEncryptedMnemonics())
        try legacyRepository.native.savePassword("legacy")

        #expect(!access.isBiometryCacheDiscarded())
    }

    @Test
    func disabledBiometryProbeKeepsMissingItemWithoutMnemonicsAsMissing() {
        let seed = "mnemonics-v2-tests-\(UUID().uuidString)"
        let legacy = makeLegacyRepository(seed: seed, keychainVault: InMemoryPasswordKeychainVault())
        let access = MnemonicAccess.disabled(mnemonicsRepository: legacy)

        // No mnemonics and no password item → genuinely absent.
        #expect(access.biometryAccessProbe() == .missing)
    }

    @Test
    func disabledBiometryProbeReturnsAccessibleForPresentItem() throws {
        let seed = "mnemonics-v2-tests-\(UUID().uuidString)"
        let legacy = makeLegacyRepository(seed: seed, keychainVault: InMemoryPasswordKeychainVault())
        let access = MnemonicAccess.disabled(mnemonicsRepository: legacy)

        try legacy.native.savePassword("secret")
        #expect(access.biometryAccessProbe() == .accessible)
    }

    @Test
    func disabledIsBiometryItemMigratedReflectsSavePassword() throws {
        let seed = "mnemonics-v2-tests-\(UUID().uuidString)"
        let legacy = makeLegacyRepository(seed: seed, keychainVault: InMemoryPasswordKeychainVault())
        let access = MnemonicAccess.disabled(mnemonicsRepository: legacy)

        #expect(!access.isBiometryItemMigrated())
        try legacy.native.savePassword("secret")
        #expect(access.isBiometryItemMigrated())
    }

    @Test
    func v2DeleteMnemonicWithoutPasscodeUsesResolvedPasscodeForLegacyDelete() async throws {
        let seed = "mnemonics-v2-tests-\(UUID().uuidString)"
        let rawStorage = makeRawStorage(
            seed: seed,
            keychain: InMemorySecureStorageKeychain()
        )
        let legacyRepository = makeLegacyRepository(
            seed: seed,
            keychainVault: InMemoryPasswordKeychainVault()
        )
        let passcodeStorage = PasscodeStorage(
            seedProvider: { seed },
            keychain: InMemorySecureStorageKeychain()
        )
        let mnemonicAccess = MnemonicAccess.v2(
            mnemonicsRepository: MnemonicAccess.ModernRepository(
                raw: rawStorage,
                unlocked: { passcode in
                    try rawStorage.unlocked(passcode: passcode)
                }
            ),
            passcodeStorage: passcodeStorage,
            legacyRepository: legacyRepository
        )
        let wallet = makeWallet(id: "wallet")
        let mnemonic = CoreMnemonic(
            mnemonicWords: TonSwift.Mnemonic.mnemonicNew(),
            type: .ton
        )
        try await mnemonicAccess.saveMnemonic(mnemonic, wallet: wallet, passcode: "1234")
        try legacyRepository.native.savePassword("1234")
        try mnemonicAccess.setPasscode("1234")
        #expect(!legacyRepository.native.hasPassword())

        try await mnemonicAccess.deleteMnemonic(wallet: wallet, passcode: nil)

        #expect(throws: MnemonicsRepositoryV2Failure.self) {
            _ = try rawStorage.unlocked(passcode: "1234").get(id: wallet.id)
        }
        #expect(try rawStorage.hasCommittedStorage())
        #expect(try rawStorage.hasMnemonic() == false)
        #expect(try rawStorage.unlocked(passcode: "any-password").getAll() == [:])
        #expect(throws: PasscodeStorageFailure.self) {
            _ = try passcodeStorage.getPasscode()
        }
        do {
            _ = try await legacyRepository.native.getMnemonic(wallet: wallet, password: "1234")
            Issue.record("Expected legacy mnemonic to be deleted")
        } catch MnemonicsVault.Error.noMnemonic {
        } catch {
            Issue.record("Expected noMnemonic, got \(error)")
        }
    }

    @Test
    func v2DeleteMissingMnemonicStillDeletesLegacyMnemonic() async throws {
        let seed = "mnemonics-v2-tests-\(UUID().uuidString)"
        let rawStorage = makeRawStorage(
            seed: seed,
            keychain: InMemorySecureStorageKeychain()
        )
        let legacyRepository = makeLegacyRepository(
            seed: seed,
            keychainVault: InMemoryPasswordKeychainVault()
        )
        let mnemonicAccess = MnemonicAccess.v2(
            mnemonicsRepository: MnemonicAccess.ModernRepository(
                raw: rawStorage,
                unlocked: { passcode in
                    try rawStorage.unlocked(passcode: passcode)
                }
            ),
            passcodeStorage: PasscodeStorage(
                seedProvider: { seed },
                keychain: InMemorySecureStorageKeychain()
            ),
            legacyRepository: legacyRepository
        )
        let targetWallet = makeWallet(id: "target_wallet")
        let otherWallet = makeWallet(id: "other_wallet")
        let targetMnemonic = CoreMnemonic(
            mnemonicWords: TonSwift.Mnemonic.mnemonicNew(),
            type: .ton
        )
        let otherMnemonic = CoreMnemonic(
            mnemonicWords: TonSwift.Mnemonic.mnemonicNew(),
            type: .ton
        )
        try rawStorage.rewrite(
            mnemonics: [otherWallet.id: otherMnemonic],
            passcode: "1234"
        )
        try await legacyRepository.native.saveMnemonic(
            KeeperCoreComponents.Mnemonic(mnemonicWords: targetMnemonic.mnemonicWords),
            wallet: targetWallet,
            password: "1234"
        )

        try await mnemonicAccess.deleteMnemonic(wallet: targetWallet, passcode: "1234")

        #expect(try rawStorage.unlocked(passcode: "1234").get(id: otherWallet.id) == otherMnemonic)
        #expect(throws: MnemonicsRepositoryV2Failure.self) {
            _ = try rawStorage.unlocked(passcode: "1234").get(id: targetWallet.id)
        }
        do {
            _ = try await legacyRepository.native.getMnemonic(wallet: targetWallet, password: "1234")
            Issue.record("Expected legacy mnemonic to be deleted")
        } catch MnemonicsVault.Error.noMnemonic {
        } catch {
            Issue.record("Expected noMnemonic, got \(error)")
        }
    }

    @Test
    func v2DeleteMnemonicWithoutCommittedStorageStillDeletesLegacyMnemonic() async throws {
        let seed = "mnemonics-v2-tests-\(UUID().uuidString)"
        let rawStorage = makeRawStorage(
            seed: seed,
            keychain: InMemorySecureStorageKeychain()
        )
        let legacyRepository = makeLegacyRepository(
            seed: seed,
            keychainVault: InMemoryPasswordKeychainVault()
        )
        let mnemonicAccess = MnemonicAccess.v2(
            mnemonicsRepository: MnemonicAccess.ModernRepository(
                raw: rawStorage,
                unlocked: { passcode in
                    try rawStorage.unlocked(passcode: passcode)
                }
            ),
            passcodeStorage: PasscodeStorage(
                seedProvider: { seed },
                keychain: InMemorySecureStorageKeychain()
            ),
            legacyRepository: legacyRepository
        )
        let wallet = makeWallet(id: "wallet")
        let mnemonic = CoreMnemonic(
            mnemonicWords: TonSwift.Mnemonic.mnemonicNew(),
            type: .ton
        )
        try await legacyRepository.native.saveMnemonic(
            KeeperCoreComponents.Mnemonic(mnemonicWords: mnemonic.mnemonicWords),
            wallet: wallet,
            password: "1234"
        )

        try await mnemonicAccess.deleteMnemonic(wallet: wallet, passcode: "1234")

        #expect(try rawStorage.hasCommittedStorage() == false)
        do {
            _ = try await legacyRepository.native.getMnemonic(wallet: wallet, password: "1234")
            Issue.record("Expected legacy mnemonic to be deleted")
        } catch MnemonicsVault.Error.noMnemonic {
        } catch {
            Issue.record("Expected noMnemonic, got \(error)")
        }
    }

    @Test
    func bip39SoftValidationRequiresDictionaryWordsOnly() {
        let words = ["abandon", "abandon", "abandon", "abandon", "abandon", "abandon", "abandon", "abandon", "abandon", "abandon", "abandon", "invalid"]
        #expect(!BIP39Mnemonic.isValidBip39SoftMnemonic(mnemonicArray: words))
    }

    @Test
    func toKeyPairThrowsForUnknownDerivationType() {
        let mnemonic = CoreMnemonic(
            mnemonicWords: ["anything"],
            type: .unknown
        )

        do {
            _ = try mnemonic.toKeyPair()
            Issue.record("Expected unknownMnemonicType")
        } catch {
            guard case .unknownMnemonicType = error else {
                Issue.record("Expected unknownMnemonicType, got \(error)")
                return
            }
        }
    }
}

private extension MnemonicsRepositoryV2Tests {
    func makeCipher(
        passcode: String,
        salt: Data? = nil,
        cost: MnemonicsRepositoryV2Crypto.Argon2Cost = .testFast
    ) throws -> MnemonicsRepositoryV2Crypto.Cipher {
        let resolvedSalt: Data
        if let salt {
            resolvedSalt = salt
        } else {
            resolvedSalt = try MnemonicsRepositoryV2Crypto.makeSalt()
        }
        return try MnemonicsRepositoryV2Crypto.unlock(
            passcode: passcode,
            salt: resolvedSalt,
            cost: cost
        )
    }

    func makeRepository(
        passcode: String,
        salt: Data? = nil,
        rawStorage: any RawMnemonicsDataRepositoryV2
    ) throws -> DefaultMnemonicsRepositoryV2 {
        let cipher = try makeCipher(passcode: passcode, salt: salt)
        func encode(
            _ mnemonic: CoreMnemonic
        ) throws(MnemonicsRepositoryV2Failure) -> RawMnemonicsData {
            do {
                return try cipher.encrypt(mnemonic)
            } catch {
                throw mnemonicsFailure(from: error)
            }
        }
        func decode(
            _ rawData: RawMnemonicsData
        ) throws(MnemonicsRepositoryV2Failure) -> CoreMnemonic {
            do {
                return try cipher.decrypt(rawData)
            } catch {
                throw mnemonicsFailure(from: error)
            }
        }
        return DefaultMnemonicsRepositoryV2(
            encoder: encode,
            decoder: decode,
            rawStorage: rawStorage
        )
    }

    func mnemonicsFailure(
        from error: MnemonicsRepositoryV2CryptoFailure
    ) -> MnemonicsRepositoryV2Failure {
        switch error {
        case let .encryptionFailure(message):
            return .encodeFailure(message: message)
        case let .decryptionFailure(message):
            return .decodeFailure(message: message)
        case let .invalidMnemonicData(message):
            return .decodeFailure(message: message)
        case let .cryptographyFailure(message):
            return .cryptographyFailure(message: message)
        }
    }

    func makeRawStorage(
        seed: String = "mnemonics-v2-tests-\(UUID().uuidString)",
        keychain: any SecureStorageKeychain
    ) -> MnemonicsRawDataRepository {
        return MnemonicsRawDataRepository(
            seedProvider: { seed },
            keychain: keychain,
            argon2Cost: .testFast
        )
    }

    func makeSaltStore(
        seed: String,
        keychain: any SecureStorageKeychain
    ) -> MnemonicsEncryptionSaltStore {
        MnemonicsEncryptionSaltStore(
            seedProvider: { seed },
            keychain: keychain
        )
    }

    func saltServiceKey(seed: String) -> String {
        "v2mnemonics_salt_\(seed)"
    }

    func rewriteMnemonicSet(
        rawStorage: MnemonicsRawDataRepository,
        passcode: String,
        mnemonic: CoreMnemonic,
        id: CoreMnemonicIdentifier = "wallet"
    ) throws {
        try rawStorage.rewrite(
            mnemonics: [id: mnemonic],
            passcode: passcode
        )
    }

    func makeV2MnemonicAccess(
        rawStorage: MnemonicsRawDataRepository,
        seed: String
    ) -> MnemonicAccess {
        return MnemonicAccess.v2(
            mnemonicsRepository: MnemonicAccess.ModernRepository(
                raw: rawStorage,
                unlocked: { passcode in
                    try rawStorage.unlocked(passcode: passcode)
                }
            ),
            passcodeStorage: PasscodeStorage(seedProvider: { seed }),
            legacyRepository: makeUnusedLegacyRepository(seed: seed)
        )
    }

    func makeUnusedLegacyRepository(seed: String) -> MnemonicAccess.LegacyRepository {
        makeLegacyRepository(
            seed: seed,
            keychainVault: UnusedKeychainVault()
        )
    }

    /// Builds an `EncryptedMnemonics` via Codable (its memberwise init is internal
    /// to KeeperCoreComponents); content is irrelevant — only presence matters for
    /// `hasMnemonics()`.
    func makeEncryptedMnemonics() throws -> EncryptedMnemonics {
        let json = #"{"kind":"encrypted-scrypt-tweetnacl","N":16384,"r":8,"p":1,"salt":"73616c74","ct":"Y2lwaGVydGV4dA=="}"#
        return try JSONDecoder().decode(EncryptedMnemonics.self, from: Data(json.utf8))
    }

    func makeLegacyRepository(
        seed: String,
        keychainVault: TKKeychainVault
    ) -> MnemonicAccess.LegacyRepository {
        return MnemonicAccess.LegacyRepository(
            rn: RNMnemonicsVault(keychainVault: keychainVault),
            native: MnemonicsVault(
                keychainVault: keychainVault,
                seedProvider: { seed }
            )
        )
    }

    func makeWallet(id: String) -> Wallet {
        let tonPublicKeyData = Data((id + "-ton-public-key").utf8) + Data(repeating: 0, count: 32)
        let tonPublicKey = TonSwift.PublicKey(data: Data(tonPublicKeyData.prefix(32)))
        return Wallet(
            id: id,
            identity: WalletIdentity(network: .mainnet, kind: .Regular(tonPublicKey, .v4R2)),
            metaData: WalletMetaData(label: id, tintColor: .SteelGray, icon: .icon(.wallet)),
            setupSettings: WalletSetupSettings(),
            batterySettings: BatterySettings()
        )
    }
}

private final class UnusedKeychainVault: TKKeychainVault {
    func exists(query: TKKeychainQuery) throws -> Bool {
        false
    }

    func biometricAccessState(query: TKKeychainQuery) -> TKKeychainBiometryAccess {
        .missing
    }

    func get(query: TKKeychainQuery) throws -> Data {
        throw TKKeychainVaultError.unexpectedData
    }

    func get(query: TKKeychainQuery) throws -> String {
        throw TKKeychainVaultError.unexpectedData
    }

    func get<T: Codable>(query: TKKeychainQuery) throws -> T {
        throw TKKeychainVaultError.unexpectedData
    }

    func set(_ value: Data, query: TKKeychainQuery) throws {}

    func set(_ value: String, query: TKKeychainQuery) throws {}

    func set<T: Codable>(_ value: T, query: TKKeychainQuery) throws {}

    func delete(_ query: TKKeychainQuery) throws {}
}

private final class InMemoryPasswordKeychainVault: TKKeychainVault {
    private var items = [String: Data]()
    private var pendingSetFailures = 0

    func exists(query: TKKeychainQuery) throws -> Bool {
        items[key(for: query)] != nil
    }

    func biometricAccessState(query: TKKeychainQuery) -> TKKeychainBiometryAccess {
        items[key(for: query)] != nil ? .accessible : .missing
    }

    func get(query: TKKeychainQuery) throws -> Data {
        guard let data = items[key(for: query)] else {
            throw TKKeychainError.noItem
        }
        return data
    }

    func get(query: TKKeychainQuery) throws -> String {
        guard let string = try String(data: get(query: query), encoding: .utf8) else {
            throw TKKeychainVaultError.unexpectedData
        }
        return string
    }

    func get<T: Codable>(query: TKKeychainQuery) throws -> T {
        let data: Data = try get(query: query)
        return try JSONDecoder().decode(T.self, from: data)
    }

    func failNextSet(times: Int) {
        pendingSetFailures = times
    }

    /// Removes a single item without touching its neighbours, so a test can
    /// reproduce a biometry-protected item that reads as not-found while the
    /// non-biometric marker beside it survives.
    func removeItem(service: String, account: String) {
        items.removeValue(forKey: "\(service):\(account)")
    }

    func set(_ value: Data, query: TKKeychainQuery) throws {
        if pendingSetFailures > 0 {
            pendingSetFailures -= 1
            throw TKKeychainError.other(errSecIO)
        }
        items[key(for: query)] = value
    }

    func set(_ value: String, query: TKKeychainQuery) throws {
        guard let data = value.data(using: .utf8) else {
            throw TKKeychainVaultError.unexpectedData
        }
        try set(data, query: query)
    }

    func set<T: Codable>(_ value: T, query: TKKeychainQuery) throws {
        try set(JSONEncoder().encode(value), query: query)
    }

    func delete(_ query: TKKeychainQuery) throws {
        guard items.removeValue(forKey: key(for: query)) != nil else {
            throw TKKeychainError.noItem
        }
    }

    private func key(for query: TKKeychainQuery) -> String {
        switch query.item {
        case let .genericPassword(service, account):
            return "\(service):\(account ?? "")"
        }
    }
}

private final class Counter {
    private(set) var value = 0

    func increment() {
        value += 1
    }
}

private final class InMemoryRawMnemonicsStorage: RawMnemonicsDataRepositoryV2 {
    private var store: [CoreMnemonicIdentifier: RawMnemonicsData] = [:]
    private let logger = LogDomain.mnemonicStorage

    func hasMnemonic() throws(MnemonicsRepositoryV2Failure) -> Bool {
        !store.isEmpty
    }

    func add(
        _ mnemonic: RawMnemonicsData,
        id: CoreMnemonicIdentifier
    ) throws(MnemonicsRepositoryV2Failure) {
        guard store[id] == nil else {
            logger.e("InMemoryRawMnemonicsStorage duplicate add attempt. id=\(id)")
            throw .duplicate
        }
        store[id] = mnemonic
    }

    func upsert(
        _ mnemonic: RawMnemonicsData,
        id: CoreMnemonicIdentifier
    ) throws(MnemonicsRepositoryV2Failure) {
        store[id] = mnemonic
    }

    func get(id: CoreMnemonicIdentifier) throws(MnemonicsRepositoryV2Failure) -> RawMnemonicsData {
        guard let value = store[id] else {
            logger.e("InMemoryRawMnemonicsStorage not found on get. id=\(id)")
            throw .notFound
        }
        return value
    }

    func getAll() throws(MnemonicsRepositoryV2Failure) -> [CoreMnemonicIdentifier: RawMnemonicsData] {
        store
    }

    func delete(id: CoreMnemonicIdentifier) throws(MnemonicsRepositoryV2Failure) {
        guard store.removeValue(forKey: id) != nil else {
            logger.e("InMemoryRawMnemonicsStorage not found on delete. id=\(id)")
            throw .notFound
        }
    }
}

extension MnemonicsRepositoryV2Crypto.Argon2Cost {
    /// libsodium Argon2id minimums (8 KiB memory, 2 passes): a few microseconds
    /// per derivation versus seconds at the production 256 MiB cost. Used by all
    /// crypto/storage tests except the explicit production-cost guard, so the
    /// suite no longer thrashes simulator memory under swift-testing's parallel
    /// execution. Test-only; the type is internal so production cannot reach it.
    static let testFast = MnemonicsRepositoryV2Crypto.Argon2Cost.custom(
        opsLimit: 2,
        memLimit: 8192
    )
}
