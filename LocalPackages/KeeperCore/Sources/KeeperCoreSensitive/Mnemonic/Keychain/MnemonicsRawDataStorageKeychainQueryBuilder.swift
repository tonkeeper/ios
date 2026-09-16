import Foundation
import Security

struct MnemonicsRawDataStorageServiceKeys: Hashable {
    let mnemonics: String
}

struct MnemonicsRawDataStorageKeychainQueryBuilder {
    let seedProvider: () -> String

    func keychainQuery(
        for type: MnemonicsRawDataStorageKeychainQuery
    ) -> [CFString: Any] {
        switch type {
        case let .checkHasMnemonics(slot):
            let serviceKeys = storageServiceKeys(slot: slot)
            return [
                kSecClass: securityClass,
                kSecAttrService: serviceKeys.mnemonics,
                kSecMatchLimit: kSecMatchLimitOne,
                kSecReturnAttributes: true,
            ]
        case let .addMnemonic(id, value, slot):
            let serviceKeys = storageServiceKeys(slot: slot)
            return [
                kSecClass: securityClass,
                kSecAttrAccessible: keychainWriteAccessType,
                kSecAttrService: serviceKeys.mnemonics,
                kSecAttrAccount: id,
                kSecValueData: value as AnyObject,
            ]
        case let .getMnemonic(id, slot):
            let serviceKeys = storageServiceKeys(slot: slot)
            return [
                kSecClass: securityClass,
                kSecAttrService: serviceKeys.mnemonics,
                kSecAttrAccount: id,
                kSecMatchLimit: kSecMatchLimitOne,
                kSecReturnData: true as AnyObject,
                kSecReturnAttributes: true as AnyObject,
            ]
        case let .getAllMnemonics(slot):
            let serviceKeys = storageServiceKeys(slot: slot)
            return [
                kSecClass: securityClass,
                kSecAttrService: serviceKeys.mnemonics,
                kSecMatchLimit: kSecMatchLimitAll,
                kSecReturnData: true as AnyObject,
                kSecReturnAttributes: true as AnyObject,
            ]
        case let .removeMnemonic(id, slot),
             let .updateMnemonic(id, slot):
            let serviceKeys = storageServiceKeys(slot: slot)
            return [
                kSecClass: securityClass,
                kSecAttrAccessible: keychainWriteAccessType,
                kSecAttrService: serviceKeys.mnemonics,
                kSecAttrAccount: id,
            ]
        case let .removeStorageArtifacts(serviceKey):
            return [
                kSecClass: securityClass,
                kSecAttrService: serviceKey,
            ]
        }
    }

    var activeStorageServiceKey: String {
        Self.activeStorageServiceKey(seed: seedProvider())
    }

    var knownStorageServiceKeys: [String] {
        let seed = seedProvider()
        return [
            Self.activeStorageServiceKey(seed: seed),
            Self.legacyReadinessMarkerServiceKey(seed: seed),
            Self.storageServiceKeys(slot: .a, seed: seed).mnemonics,
            Self.storageServiceKeys(slot: .b, seed: seed).mnemonics,
        ]
    }

    var keychainWriteAccessType: Any {
        kSecAttrAccessibleWhenUnlockedThisDeviceOnly
    }
}

extension MnemonicsRawDataStorageKeychainQueryBuilder {
    func storageServiceKeys(slot: ABStorageSlot) -> MnemonicsRawDataStorageServiceKeys {
        Self.storageServiceKeys(
            slot: slot,
            seed: seedProvider()
        )
    }

    var securityClass: Any {
        kSecClassGenericPassword
    }

    static func activeStorageServiceKey(seed: String) -> String {
        "v2mnemonics_active_slot_\(seed)"
    }

    static func legacyReadinessMarkerServiceKey(seed: String) -> String {
        "v2mnemonics_marker_\(seed)"
    }

    static func storageServiceKeys(
        slot: ABStorageSlot,
        seed: String
    ) -> MnemonicsRawDataStorageServiceKeys {
        switch slot {
        case .a:
            MnemonicsRawDataStorageServiceKeys(
                mnemonics: "v2mnemonics_\(seed)"
            )
        case .b:
            MnemonicsRawDataStorageServiceKeys(
                mnemonics: "v2mnemonics_b_\(seed)"
            )
        }
    }
}
