import Foundation
@testable import KeeperCoreSensitive
import Security

final class InMemorySecureStorageKeychain: SecureStorageKeychain {
    private struct ItemKey: Hashable {
        let service: String
        let account: String
    }

    private struct ServiceQueryKey: Hashable {
        let service: String
        let account: String?
    }

    private var items = [ItemKey: Data]()
    private var copyFailures = [ServiceQueryKey: OSStatus]()
    private var addFailures = [ItemKey: OSStatus]()
    private var updateFailures = [ItemKey: OSStatus]()
    private var deleteFailures = [ServiceQueryKey: OSStatus]()

    func setCopyFailure(
        service: String,
        account: String? = nil,
        status: OSStatus
    ) {
        copyFailures[ServiceQueryKey(service: service, account: account)] = status
    }

    func setAddFailure(
        service: String,
        account: String,
        status: OSStatus
    ) {
        addFailures[ItemKey(service: service, account: account)] = status
    }

    func setUpdateFailure(
        service: String,
        account: String,
        status: OSStatus
    ) {
        updateFailures[ItemKey(service: service, account: account)] = status
    }

    func setDeleteFailure(
        service: String,
        account: String? = nil,
        status: OSStatus
    ) {
        deleteFailures[ServiceQueryKey(service: service, account: account)] = status
    }

    func containsItem(
        service: String,
        account: String
    ) -> Bool {
        items[ItemKey(service: service, account: account)] != nil
    }

    func removeItem(
        service: String,
        account: String
    ) {
        items.removeValue(forKey: ItemKey(service: service, account: account))
    }

    func setItem(
        service: String,
        account: String,
        data: Data
    ) {
        items[ItemKey(service: service, account: account)] = data
    }

    func removeItems(service: String) {
        items = items.filter { $0.key.service != service }
    }

    func copyMatching(
        _ query: CFDictionary,
        result: UnsafeMutablePointer<CFTypeRef?>?
    ) -> OSStatus {
        guard let service = stringValue(kSecAttrService, in: query) else {
            return errSecParam
        }
        let account = stringValue(kSecAttrAccount, in: query)
        if let status = copyFailureStatus(service: service, account: account) {
            return status
        }

        if cfValue(kSecMatchLimit, in: query, equals: kSecMatchLimitAll) {
            let matchingItems = items
                .filter { $0.key.service == service }
                .sorted { $0.key.account < $1.key.account }
            guard !matchingItems.isEmpty else {
                return errSecItemNotFound
            }
            result?.pointee = matchingItems.map { item in
                keychainResultDictionary(
                    account: item.key.account,
                    data: item.value,
                    query: query
                )
            } as NSArray
            return errSecSuccess
        }

        guard let item = firstMatchingItem(service: service, account: account) else {
            return errSecItemNotFound
        }
        result?.pointee = keychainResult(
            account: item.key.account,
            data: item.value,
            query: query
        )
        return errSecSuccess
    }

    func add(
        _ query: CFDictionary,
        result _: UnsafeMutablePointer<CFTypeRef?>?
    ) -> OSStatus {
        guard let service = stringValue(kSecAttrService, in: query),
              let account = stringValue(kSecAttrAccount, in: query),
              let data = dataValue(kSecValueData, in: query)
        else {
            return errSecParam
        }
        let key = ItemKey(service: service, account: account)
        if let status = addFailures[key] {
            return status
        }
        guard items[key] == nil else {
            return errSecDuplicateItem
        }
        items[key] = data
        return errSecSuccess
    }

    func update(
        _ query: CFDictionary,
        attributes: CFDictionary
    ) -> OSStatus {
        guard let service = stringValue(kSecAttrService, in: query),
              let account = stringValue(kSecAttrAccount, in: query),
              let data = dataValue(kSecValueData, in: attributes)
        else {
            return errSecParam
        }
        let key = ItemKey(service: service, account: account)
        if let status = updateFailures[key] {
            return status
        }
        guard items[key] != nil else {
            return errSecItemNotFound
        }
        items[key] = data
        return errSecSuccess
    }

    func delete(_ query: CFDictionary) -> OSStatus {
        // SecItemDelete rejects search-only and return keys with errSecParam,
        // regardless of whether a matching item exists. Reproduced here so a
        // query reused between copyMatching and delete cannot pass in tests and
        // fail on device.
        let keysRejectedByDelete: [CFString] = [
            kSecMatchLimit,
            kSecReturnData,
            kSecReturnAttributes,
            kSecReturnRef,
            kSecReturnPersistentRef,
        ]
        guard keysRejectedByDelete.allSatisfy({ (query as NSDictionary)[$0] == nil }) else {
            return errSecParam
        }
        guard let service = stringValue(kSecAttrService, in: query) else {
            return errSecParam
        }
        let account = stringValue(kSecAttrAccount, in: query)
        if let status = deleteFailureStatus(service: service, account: account) {
            return status
        }
        if let account {
            let key = ItemKey(service: service, account: account)
            guard items.removeValue(forKey: key) != nil else {
                return errSecItemNotFound
            }
            return errSecSuccess
        }
        let existingKeys = items.keys.filter { $0.service == service }
        guard !existingKeys.isEmpty else {
            return errSecItemNotFound
        }
        for key in existingKeys {
            items.removeValue(forKey: key)
        }
        return errSecSuccess
    }

    private func copyFailureStatus(
        service: String,
        account: String?
    ) -> OSStatus? {
        if let status = copyFailures[ServiceQueryKey(service: service, account: account)] {
            return status
        }
        if account != nil {
            return copyFailures[ServiceQueryKey(service: service, account: nil)]
        }
        return nil
    }

    private func deleteFailureStatus(
        service: String,
        account: String?
    ) -> OSStatus? {
        if let status = deleteFailures[ServiceQueryKey(service: service, account: account)] {
            return status
        }
        if account != nil {
            return deleteFailures[ServiceQueryKey(service: service, account: nil)]
        }
        return nil
    }

    private func firstMatchingItem(
        service: String,
        account: String?
    ) -> (key: ItemKey, value: Data)? {
        if let account {
            let key = ItemKey(service: service, account: account)
            guard let value = items[key] else {
                return nil
            }
            return (key, value)
        }
        guard let key = items.keys.filter({ $0.service == service }).min(by: { $0.account < $1.account }),
              let value = items[key]
        else {
            return nil
        }
        return (key, value)
    }

    private func keychainResult(
        account: String,
        data: Data,
        query: CFDictionary
    ) -> CFTypeRef? {
        if boolValue(kSecReturnAttributes, in: query) {
            return keychainResultDictionary(
                account: account,
                data: data,
                query: query
            ) as CFTypeRef
        }
        if boolValue(kSecReturnData, in: query) {
            return data as CFTypeRef
        }
        return nil
    }

    private func keychainResultDictionary(
        account: String,
        data: Data,
        query: CFDictionary
    ) -> [String: Any] {
        var dictionary: [String: Any] = [
            kSecAttrAccount as String: account,
        ]
        if boolValue(kSecReturnData, in: query) {
            dictionary[kSecValueData as String] = data
        }
        return dictionary
    }

    private func stringValue(_ key: CFString, in dictionary: CFDictionary) -> String? {
        (dictionary as NSDictionary)[key] as? String
    }

    private func dataValue(_ key: CFString, in dictionary: CFDictionary) -> Data? {
        (dictionary as NSDictionary)[key] as? Data
    }

    private func boolValue(_ key: CFString, in dictionary: CFDictionary) -> Bool {
        ((dictionary as NSDictionary)[key] as? Bool) == true
    }

    private func cfValue(
        _ key: CFString,
        in dictionary: CFDictionary,
        equals expected: CFString
    ) -> Bool {
        guard let value = (dictionary as NSDictionary)[key] else {
            return false
        }
        return CFEqual(value as CFTypeRef, expected)
    }
}
