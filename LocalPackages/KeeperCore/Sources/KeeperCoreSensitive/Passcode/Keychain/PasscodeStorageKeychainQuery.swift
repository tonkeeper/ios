import Foundation
import LocalAuthentication

enum PasscodeStorageKeychainQuery: Hashable {
    case checkEncryptedPasscode(slot: ABStorageSlot)
    case addEncryptedPasscode(value: Data, slot: ABStorageSlot)
    case getEncryptedPasscode(slot: ABStorageSlot)
    case updateEncryptedPasscode(slot: ABStorageSlot)
    case removeEncryptedPasscode(slot: ABStorageSlot)
    case checkWrapKey(context: LAContext, slot: ABStorageSlot)
    case addWrapKey(
        value: Data,
        accessControl: SecAccessControl,
        slot: ABStorageSlot
    )
    case getWrapKey(context: LAContext, slot: ABStorageSlot)
    case updateWrapKey(slot: ABStorageSlot)
    case removeWrapKey(slot: ABStorageSlot)

    case removeEncryptedPasscodeLegacy
    case removeWrapKeyLegacy
}
