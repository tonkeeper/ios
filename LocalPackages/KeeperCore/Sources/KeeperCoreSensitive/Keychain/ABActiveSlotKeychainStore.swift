import Foundation
import Security

enum ABActiveSlotState: Equatable {
    case uninitialized
    case initialized(ABStorageSlot)
}

struct ABActiveSlotKeychainStore {
    enum Error: Swift.Error {
        case invalidData(String)
        case unexpectedStatus(OSStatus)
    }

    private let serviceKey: String
    private let accountKey: String
    private let keychainWriteAccessType: Any
    private let keychain: any SecureStorageKeychain

    init(
        serviceKey: String,
        accountKey: String = "active_slot",
        keychainWriteAccessType: Any,
        keychain: any SecureStorageKeychain
    ) {
        self.serviceKey = serviceKey
        self.accountKey = accountKey
        self.keychainWriteAccessType = keychainWriteAccessType
        self.keychain = keychain
    }

    func activeSlotState() throws(Error) -> ABActiveSlotState {
        let query = keychainQuery(for: .get) as CFDictionary
        var item: CFTypeRef?
        let status = keychain.copyMatching(query, result: &item)
        switch status {
        case errSecItemNotFound:
            return .uninitialized
        case errSecSuccess:
            break
        default:
            throw .unexpectedStatus(status)
        }

        guard
            let data = item as? Data,
            let value = String(data: data, encoding: .utf8),
            let slot = ABStorageSlot(rawValue: value)
        else {
            throw .invalidData("\(String(describing: item))")
        }
        return .initialized(slot)
    }

    func setActiveSlot(_ slot: ABStorageSlot) throws(Error) {
        let value = Data(slot.rawValue.utf8)
        let addStatus = keychain.add(
            keychainQuery(for: .set(value: value)) as CFDictionary,
            result: nil
        )
        switch addStatus {
        case errSecSuccess:
            return
        case errSecDuplicateItem:
            break
        default:
            throw .unexpectedStatus(addStatus)
        }

        let updateStatus = keychain.update(
            keychainQuery(for: .update) as CFDictionary,
            attributes: [
                kSecValueData: value as AnyObject,
            ] as CFDictionary
        )
        guard updateStatus == errSecSuccess else {
            throw .unexpectedStatus(updateStatus)
        }
    }

    func deleteActiveSlot() throws(Error) {
        let status = keychain.delete(
            keychainQuery(for: .remove) as CFDictionary
        )
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw .unexpectedStatus(status)
        }
    }
}

private extension ABActiveSlotKeychainStore {
    enum QueryType {
        case get
        case set(value: Data)
        case update
        case remove
    }

    func keychainQuery(for type: QueryType) -> [CFString: Any] {
        switch type {
        case .get:
            return [
                kSecClass: securityClass,
                kSecAttrService: serviceKey,
                kSecAttrAccount: accountKey,
                kSecMatchLimit: kSecMatchLimitOne,
                kSecReturnData: true as AnyObject,
            ]
        case let .set(value):
            return [
                kSecClass: securityClass,
                kSecAttrAccessible: keychainWriteAccessType,
                kSecAttrService: serviceKey,
                kSecAttrAccount: accountKey,
                kSecValueData: value as AnyObject,
            ]
        case .update,
             .remove:
            return [
                kSecClass: securityClass,
                kSecAttrService: serviceKey,
                kSecAttrAccount: accountKey,
            ]
        }
    }

    var securityClass: Any {
        kSecClassGenericPassword
    }
}
