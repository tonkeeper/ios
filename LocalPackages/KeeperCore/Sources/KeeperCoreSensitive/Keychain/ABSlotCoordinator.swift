import Foundation

enum ABSlotCoordinatorFailure<StorageFailure: Error>: Error {
    case activeSlot(ABActiveSlotKeychainStore.Error)
    case storage(StorageFailure)
    case unexpectedStagedSlot(expected: ABStorageSlot, actual: ABStorageSlot)
    case stagedDiscardFailed(original: StorageFailure, discard: StorageFailure)
    case activationCleanupFailed(
        original: ABActiveSlotKeychainStore.Error,
        discard: StorageFailure
    )
}

protocol ABSlotStorage {
    associatedtype WriteInput
    associatedtype Failure: Error

    var slot: ABStorageSlot { get }
    func prepare() throws(Failure)
    func write(_ input: WriteInput) throws(Failure)
}

protocol ABSlotDataPresenceCheckingStorage: ABSlotStorage {
    func hasData() throws(Failure) -> Bool
}

struct ABSlotCommit<Storage: ABSlotStorage> {
    let previousStorage: Storage?
    let stagedStorage: Storage

    var previousSlot: ABStorageSlot? {
        previousStorage?.slot
    }

    var stagedSlot: ABStorageSlot {
        stagedStorage.slot
    }
}

struct ABSlotCoordinator<Storage: ABSlotStorage> {
    typealias Failure = ABSlotCoordinatorFailure<Storage.Failure>

    private let activeSlotStore: ABActiveSlotKeychainStore
    private let makeStorage: (ABStorageSlot) -> Storage

    init(
        activeSlotStore: ABActiveSlotKeychainStore,
        makeStorage: @escaping (ABStorageSlot) -> Storage
    ) {
        self.activeSlotStore = activeSlotStore
        self.makeStorage = makeStorage
    }

    @discardableResult
    func commit(_ input: Storage.WriteInput) throws(Failure) -> ABSlotCommit<Storage> {
        let activeSlotState: ABActiveSlotState
        do {
            activeSlotState = try activeSlotStore.activeSlotState()
        } catch {
            throw .activeSlot(error)
        }

        let previousStorage: Storage?
        let expectedStagedSlot: ABStorageSlot
        switch activeSlotState {
        case .uninitialized:
            previousStorage = nil
            expectedStagedSlot = .a
        case let .initialized(activeSlot):
            previousStorage = makeStorage(activeSlot)
            expectedStagedSlot = activeSlot.inactive
        }
        let stagedStorage = makeStorage(expectedStagedSlot)

        guard stagedStorage.slot == expectedStagedSlot else {
            throw .unexpectedStagedSlot(
                expected: expectedStagedSlot,
                actual: stagedStorage.slot
            )
        }

        do {
            try stagedStorage.prepare()
            try stagedStorage.write(input)
        } catch let original {
            do {
                try stagedStorage.prepare()
            } catch let discard {
                throw .stagedDiscardFailed(
                    original: original,
                    discard: discard
                )
            }
            throw .storage(original)
        }

        do {
            try activeSlotStore.setActiveSlot(stagedStorage.slot)
        } catch let original {
            do {
                try stagedStorage.prepare()
            } catch let discard {
                throw .activationCleanupFailed(
                    original: original,
                    discard: discard
                )
            }
            throw .activeSlot(original)
        }

        return ABSlotCommit(
            previousStorage: previousStorage,
            stagedStorage: stagedStorage
        )
    }

    func activeStorage() throws(Failure) -> Storage? {
        let activeSlotState: ABActiveSlotState
        do {
            activeSlotState = try activeSlotStore.activeSlotState()
        } catch {
            throw .activeSlot(error)
        }

        switch activeSlotState {
        case .uninitialized:
            return nil
        case let .initialized(activeSlot):
            return makeStorage(activeSlot)
        }
    }
}

extension ABSlotCoordinator where Storage: ABSlotDataPresenceCheckingStorage {
    func hasData() throws(Failure) -> Bool {
        guard let activeStorage = try activeStorage() else {
            return false
        }
        do {
            return try activeStorage.hasData()
        } catch {
            throw .storage(error)
        }
    }
}
