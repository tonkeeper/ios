import Foundation

enum MnemonicsRawDataStorageKeychainQuery: Hashable {
    case checkHasMnemonics(slot: ABStorageSlot)
    case addMnemonic(
        id: CoreMnemonicIdentifier,
        value: Data,
        slot: ABStorageSlot
    )
    case updateMnemonic(
        id: CoreMnemonicIdentifier,
        slot: ABStorageSlot
    )
    case getAllMnemonics(slot: ABStorageSlot)
    case getMnemonic(
        id: CoreMnemonicIdentifier,
        slot: ABStorageSlot
    )
    case removeMnemonic(
        id: CoreMnemonicIdentifier,
        slot: ABStorageSlot
    )
    case removeStorageArtifacts(serviceKey: String)
}
