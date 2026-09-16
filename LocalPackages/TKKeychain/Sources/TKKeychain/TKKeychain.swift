import Foundation
import LocalAuthentication

public enum TKKeychainAccessible {
    case whenUnlocked
    case afterFirstUnlock
    case whenPasscodeSetThisDeviceOnly
    case whenUnlockedThisDeviceOnly
    case afterFirstUnlockThisDeviceOnly

    public var keychainKey: CFString {
        switch self {
        case .afterFirstUnlock:
            return kSecAttrAccessibleAfterFirstUnlock
        case .afterFirstUnlockThisDeviceOnly:
            return kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        case .whenPasscodeSetThisDeviceOnly:
            return kSecAttrAccessibleWhenPasscodeSetThisDeviceOnly
        case .whenUnlocked:
            return kSecAttrAccessibleWhenUnlocked
        case .whenUnlockedThisDeviceOnly:
            return kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        }
    }
}

public enum TKKeychainBiometry {
    case none
    case current
}

/// Non-interactive probe of a biometry-protected item's access control.
/// Distinguishes an invalidated enrolled set from a plain absent item, which a
/// bare presence check cannot: an invalidated `biometryCurrentSet` item is hidden
/// from an attribute-only read (reports `errSecItemNotFound`) yet still exists.
public enum TKKeychainBiometryAccess {
    /// Access control still satisfiable — a real read would prompt for biometry.
    case accessible
    /// Enrolled biometric set changed — the access control can no longer be met.
    case invalidated
    /// No such item.
    case missing
    /// Unexpected keychain error; be conservative.
    case indeterminate
}

public enum TKKeychainItem {
    case genericPassword(service: String, account: String?)
}

public struct TKKeychainQuery {
    public let item: TKKeychainItem
    public let accessGroup: String?
    public let biometry: TKKeychainBiometry
    public let accessible: TKKeychainAccessible

    /// Search attributes only. Protection attributes (`kSecAttrAccessible`,
    /// `kSecAttrAccessControl`) are creation-time and must not participate in
    /// matching, so items written with an older access control (e.g. biometryAny)
    /// stay readable and deletable.
    var searchQuery: [CFString: AnyObject] {
        var query = [CFString: AnyObject]()
        switch item {
        case let .genericPassword(service, account):
            query[kSecClass] = kSecClassGenericPassword
            query[kSecAttrService] = service as AnyObject
            if let account {
                query[kSecAttrAccount] = account as AnyObject
            }
        }

        if let accessGroup {
            query[kSecAttrAccessGroup] = accessGroup as AnyObject
        }

        return query
    }

    var addQuery: [CFString: AnyObject] {
        var query = searchQuery

        switch biometry {
        case .none:
            query[kSecAttrAccessible] = accessible.keychainKey
        case .current:
            let accessOptions = SecAccessControlCreateWithFlags(
                kCFAllocatorDefault,
                accessible.keychainKey,
                SecAccessControlCreateFlags.biometryCurrentSet,
                nil
            )
            query[kSecAttrAccessControl] = accessOptions
        }

        return query
    }

    public init(
        item: TKKeychainItem,
        accessGroup: String?,
        biometry: TKKeychainBiometry,
        accessible: TKKeychainAccessible
    ) {
        self.item = item
        self.accessGroup = accessGroup
        self.biometry = biometry
        self.accessible = accessible
    }
}

public struct TKKeychainAttributes {
    public let data: Data

    var attributes: [CFString: AnyObject] {
        var attributes = [CFString: AnyObject]()
        attributes[kSecValueData] = data as AnyObject
        return attributes
    }
}

enum TKKeychainStatus {
    case success
    case failure(TKKeychainError)

    init(status: OSStatus) {
        switch status {
        case noErr:
            self = .success
        default:
            self = .failure(TKKeychainError(status: status))
        }
    }
}

public enum TKKeychainError: Swift.Error {
    case corruptedData
    case noItem
    case other(OSStatus)

    init(status: OSStatus) {
        switch status {
        case errSecItemNotFound:
            self = .noItem
        default:
            self = .other(status)
        }
    }
}

public protocol TKKeychain {
    func add(data: Data, query: TKKeychainQuery) throws
    func exists(query: TKKeychainQuery) throws -> Bool
    func biometricAccessState(query: TKKeychainQuery) -> TKKeychainBiometryAccess
    func get(query: TKKeychainQuery) throws -> Data?
    func update(query: TKKeychainQuery, attributes: TKKeychainAttributes) throws
    func delete(query: TKKeychainQuery) throws
}

public final class TKKeychainImplementation: TKKeychain {
    public init() {}

    public func add(data: Data, query: TKKeychainQuery) throws {
        var query = query.addQuery
        query[kSecValueData] = data as AnyObject

        let status = SecItemAdd(query as CFDictionary, nil)
        let keychainStatus = TKKeychainStatus(status: status)
        switch keychainStatus {
        case .success:
            return
        case let .failure(keychainError):
            throw keychainError
        }
    }

    public func exists(query queryInput: TKKeychainQuery) throws -> Bool {
        var query = queryInput.searchQuery
        query[kSecMatchLimit] = kSecMatchLimitOne
        query[kSecReturnAttributes] = kCFBooleanTrue
        let context = LAContext()
        context.interactionNotAllowed = true
        query[kSecUseAuthenticationContext] = context

        var result: AnyObject?
        let status = withUnsafeMutablePointer(to: &result) {
            SecItemCopyMatching(query as CFDictionary, UnsafeMutablePointer($0))
        }

        switch status {
        case errSecSuccess, errSecInteractionNotAllowed, errSecAuthFailed:
            // errSecAuthFailed: a present item whose access control can no longer
            // be satisfied. NOTE: this is the Simulator behavior — on a real
            // device an invalidated biometryCurrentSet item instead returns
            // errSecItemNotFound (see `biometricAccessState`), so this branch does
            // not catch the device case. `hasPassword` therefore reports false for
            // an invalidated item on device; recovery does not depend on it (it
            // keys off `biometricAccessState` plus the biometry-migrated marker),
            // so this is safe.
            return true
        case errSecItemNotFound:
            return false
        default:
            throw TKKeychainError(status: status)
        }
    }

    public func biometricAccessState(query queryInput: TKKeychainQuery) -> TKKeychainBiometryAccess {
        var query = queryInput.searchQuery
        query[kSecMatchLimit] = kSecMatchLimitOne
        // A data read forces access-control evaluation without prompting
        // (`interactionNotAllowed`): a still-valid item reports
        // `errSecInteractionNotAllowed` (→ .accessible). An invalidated
        // `biometryCurrentSet` item reports `errSecAuthFailed` (→ .invalidated) on
        // the Simulator, but `errSecItemNotFound` (→ .missing) on a real device —
        // there it is indistinguishable from a truly absent item by status alone.
        // That `.missing`-vs-absent ambiguity is resolved one layer up in
        // `MnemonicAccess.biometryAccessProbe()` via the non-biometry `hasMnemonics()`.
        query[kSecReturnData] = kCFBooleanTrue
        let context = LAContext()
        context.interactionNotAllowed = true
        query[kSecUseAuthenticationContext] = context

        var result: AnyObject?
        let status = withUnsafeMutablePointer(to: &result) {
            SecItemCopyMatching(query as CFDictionary, UnsafeMutablePointer($0))
        }

        let state: TKKeychainBiometryAccess
        switch status {
        case errSecSuccess, errSecInteractionNotAllowed:
            state = .accessible
        case errSecAuthFailed:
            state = .invalidated
        case errSecItemNotFound:
            state = .missing
        default:
            state = .indeterminate
        }
        return state
    }

    public func get(query: TKKeychainQuery) throws -> Data? {
        var query = query.searchQuery
        query[kSecMatchLimit] = kSecMatchLimitOne
        query[kSecReturnData] = kCFBooleanTrue

        var result: AnyObject?
        let status = withUnsafeMutablePointer(to: &result) {
            SecItemCopyMatching(query as CFDictionary, UnsafeMutablePointer($0))
        }

        let keychainStatus = TKKeychainStatus(status: status)
        switch keychainStatus {
        case .success:
            return result as? Data
        case let .failure(keychainError):
            throw keychainError
        }
    }

    public func update(query: TKKeychainQuery, attributes: TKKeychainAttributes) throws {
        let status = SecItemUpdate(
            query.searchQuery as CFDictionary,
            attributes.attributes as CFDictionary
        )

        let keychainStatus = TKKeychainStatus(status: status)
        switch keychainStatus {
        case .success:
            return
        case let .failure(keychainError):
            throw keychainError
        }
    }

    public func delete(query: TKKeychainQuery) throws {
        let query = query.searchQuery
        let status = SecItemDelete(query as CFDictionary)

        let keychainStatus = TKKeychainStatus(status: status)
        switch keychainStatus {
        case .success:
            return
        case let .failure(keychainError):
            throw keychainError
        }
    }
}
