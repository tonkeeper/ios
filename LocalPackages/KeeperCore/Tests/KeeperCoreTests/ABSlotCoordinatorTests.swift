import Foundation
@testable import KeeperCoreSensitive
import Security
import Testing

struct ABSlotCoordinatorTests {
    @Test
    func firstCommitActivatesSlotA() throws {
        let keychain = InMemorySecureStorageKeychain()
        let service = "ab-slot-coordinator-tests-\(UUID().uuidString)"
        let recorder = TestStorage.Recorder()
        let coordinator = makeCoordinator(
            service: service,
            keychain: keychain,
            recorder: recorder
        )

        let commit = try coordinator.commit("payload")

        #expect(commit.previousSlot == nil)
        #expect(commit.stagedSlot == .a)
        #expect(recorder.events == [.prepare(.a), .write(.a, "payload")])
        #expect(try makeActiveSlotStore(service: service, keychain: keychain).activeSlotState() == .initialized(.a))
    }

    @Test
    func repeatedCommitActivatesInactiveSlot() throws {
        let keychain = InMemorySecureStorageKeychain()
        let service = "ab-slot-coordinator-tests-\(UUID().uuidString)"
        let store = makeActiveSlotStore(service: service, keychain: keychain)
        try store.setActiveSlot(.a)
        let recorder = TestStorage.Recorder()
        let coordinator = ABSlotCoordinator(
            activeSlotStore: store,
            makeStorage: { TestStorage(slot: $0, recorder: recorder) }
        )

        let commit = try coordinator.commit("payload")

        #expect(commit.previousSlot == .a)
        #expect(commit.stagedSlot == .b)
        #expect(recorder.events == [.prepare(.b), .write(.b, "payload")])
        #expect(try store.activeSlotState() == .initialized(.b))
    }

    @Test
    func writeFailureDiscardsStagedAndKeepsUninitializedPointer() throws {
        let keychain = InMemorySecureStorageKeychain()
        let service = "ab-slot-coordinator-tests-\(UUID().uuidString)"
        let recorder = TestStorage.Recorder()
        let coordinator = makeCoordinator(
            service: service,
            keychain: keychain,
            recorder: recorder,
            writeError: .write
        )

        do {
            _ = try coordinator.commit("payload")
            Issue.record("Expected write failure")
        } catch {
            guard case .storage(.write) = error else {
                Issue.record("Expected write failure, got \(error)")
                return
            }
        }

        #expect(recorder.events == [.prepare(.a), .write(.a, "payload"), .prepare(.a)])
        #expect(try makeActiveSlotStore(service: service, keychain: keychain).activeSlotState() == .uninitialized)
    }

    @Test
    func writeFailureDiscardsStagedAndKeepsPreviousSlot() throws {
        let keychain = InMemorySecureStorageKeychain()
        let service = "ab-slot-coordinator-tests-\(UUID().uuidString)"
        let store = makeActiveSlotStore(service: service, keychain: keychain)
        try store.setActiveSlot(.a)
        let recorder = TestStorage.Recorder()
        let coordinator = ABSlotCoordinator(
            activeSlotStore: store,
            makeStorage: {
                TestStorage(
                    slot: $0,
                    recorder: recorder,
                    writeError: .write
                )
            }
        )

        do {
            _ = try coordinator.commit("payload")
            Issue.record("Expected write failure")
        } catch {
            guard case .storage(.write) = error else {
                Issue.record("Expected write failure, got \(error)")
                return
            }
        }

        #expect(recorder.events == [.prepare(.b), .write(.b, "payload"), .prepare(.b)])
        #expect(try store.activeSlotState() == .initialized(.a))
    }

    @Test
    func discardFailureBeforeActivationWrapsOriginalError() throws {
        let recorder = TestStorage.Recorder()
        let coordinator = makeCoordinator(
            recorder: recorder,
            writeError: .write,
            secondPrepareError: .discard
        )

        do {
            _ = try coordinator.commit("payload")
            Issue.record("Expected staged discard failure")
        } catch {
            guard case .stagedDiscardFailed(.write, .discard) = error else {
                Issue.record("Expected stagedDiscardFailed, got \(error)")
                return
            }
        }
    }

    @Test
    func activationFailureDiscardsStagedAndKeepsPreviousSlot() throws {
        let keychain = InMemorySecureStorageKeychain()
        let service = "ab-slot-coordinator-tests-\(UUID().uuidString)"
        let store = makeActiveSlotStore(service: service, keychain: keychain)
        try store.setActiveSlot(.a)
        keychain.setUpdateFailure(
            service: service,
            account: "active_slot",
            status: errSecInteractionNotAllowed
        )
        let recorder = TestStorage.Recorder()
        let coordinator = ABSlotCoordinator(
            activeSlotStore: store,
            makeStorage: { TestStorage(slot: $0, recorder: recorder) }
        )

        do {
            _ = try coordinator.commit("payload")
            Issue.record("Expected activation failure")
        } catch {
            guard case let .activeSlot(.unexpectedStatus(status)) = error else {
                Issue.record("Expected active slot update failure, got \(error)")
                return
            }
            #expect(status == errSecInteractionNotAllowed)
        }

        #expect(recorder.events == [.prepare(.b), .write(.b, "payload"), .prepare(.b)])
        keychain.setUpdateFailure(
            service: service,
            account: "active_slot",
            status: errSecSuccess
        )
        #expect(try store.activeSlotState() == .initialized(.a))
    }

    @Test
    func activationCleanupFailureWrapsOriginalError() throws {
        let keychain = InMemorySecureStorageKeychain()
        let service = "ab-slot-coordinator-tests-\(UUID().uuidString)"
        let store = makeActiveSlotStore(service: service, keychain: keychain)
        try store.setActiveSlot(.a)
        keychain.setUpdateFailure(
            service: service,
            account: "active_slot",
            status: errSecInteractionNotAllowed
        )
        let recorder = TestStorage.Recorder()
        let coordinator = ABSlotCoordinator(
            activeSlotStore: store,
            makeStorage: {
                TestStorage(
                    slot: $0,
                    recorder: recorder,
                    secondPrepareError: .discard
                )
            }
        )

        do {
            _ = try coordinator.commit("payload")
            Issue.record("Expected activation cleanup failure")
        } catch {
            guard case let .activationCleanupFailed(.unexpectedStatus(status), .discard) = error else {
                Issue.record("Expected activationCleanupFailed, got \(error)")
                return
            }
            #expect(status == errSecInteractionNotAllowed)
        }
    }

    @Test
    func unexpectedFactorySlotFailsBeforePrepare() throws {
        let recorder = TestStorage.Recorder()
        let coordinator = ABSlotCoordinator(
            activeSlotStore: makeActiveSlotStore(
                service: "ab-slot-coordinator-tests-\(UUID().uuidString)",
                keychain: InMemorySecureStorageKeychain()
            ),
            makeStorage: { _ in TestStorage(slot: .b, recorder: recorder) }
        )

        do {
            _ = try coordinator.commit("payload")
            Issue.record("Expected staged slot mismatch")
        } catch {
            guard case let .unexpectedStagedSlot(expected, actual) = error else {
                Issue.record("Expected unexpectedStagedSlot, got \(error)")
                return
            }
            #expect(expected == .a)
            #expect(actual == .b)
        }

        #expect(recorder.events.isEmpty)
    }
}

private extension ABSlotCoordinatorTests {
    enum TestError: Swift.Error, Equatable {
        case write
        case discard
    }

    final class TestStorage: ABSlotStorage {
        typealias WriteInput = String
        typealias Failure = TestError

        final class Recorder {
            var events = [Event]()
            var prepareCounts = [ABStorageSlot: Int]()
        }

        enum Event: Equatable {
            case prepare(ABStorageSlot)
            case write(ABStorageSlot, String)
        }

        let slot: ABStorageSlot
        let recorder: Recorder
        let writeError: TestError?
        let secondPrepareError: TestError?

        init(
            slot: ABStorageSlot,
            recorder: Recorder,
            writeError: TestError? = nil,
            secondPrepareError: TestError? = nil
        ) {
            self.slot = slot
            self.recorder = recorder
            self.writeError = writeError
            self.secondPrepareError = secondPrepareError
        }

        func prepare() throws(TestError) {
            let prepareCount = (recorder.prepareCounts[slot] ?? 0) + 1
            recorder.prepareCounts[slot] = prepareCount
            recorder.events.append(.prepare(slot))
            if prepareCount == 2, let secondPrepareError {
                throw secondPrepareError
            }
        }

        func write(_ input: String) throws(TestError) {
            recorder.events.append(.write(slot, input))
            if let writeError {
                throw writeError
            }
        }
    }

    func makeCoordinator(
        service: String = "ab-slot-coordinator-tests-\(UUID().uuidString)",
        keychain: InMemorySecureStorageKeychain = InMemorySecureStorageKeychain(),
        recorder: TestStorage.Recorder,
        writeError: TestError? = nil,
        secondPrepareError: TestError? = nil
    ) -> ABSlotCoordinator<TestStorage> {
        ABSlotCoordinator(
            activeSlotStore: makeActiveSlotStore(
                service: service,
                keychain: keychain
            ),
            makeStorage: {
                TestStorage(
                    slot: $0,
                    recorder: recorder,
                    writeError: writeError,
                    secondPrepareError: secondPrepareError
                )
            }
        )
    }

    func makeActiveSlotStore(
        service: String,
        keychain: InMemorySecureStorageKeychain
    ) -> ABActiveSlotKeychainStore {
        ABActiveSlotKeychainStore(
            serviceKey: service,
            keychainWriteAccessType: kSecAttrAccessibleWhenUnlocked,
            keychain: keychain
        )
    }
}
