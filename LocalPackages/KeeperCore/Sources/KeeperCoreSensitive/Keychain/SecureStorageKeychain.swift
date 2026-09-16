import Foundation
import Security

protocol SecureStorageKeychain {
    func copyMatching(
        _ query: CFDictionary,
        result: UnsafeMutablePointer<CFTypeRef?>?
    ) -> OSStatus
    func add(
        _ query: CFDictionary,
        result: UnsafeMutablePointer<CFTypeRef?>?
    ) -> OSStatus
    func update(
        _ query: CFDictionary,
        attributes: CFDictionary
    ) -> OSStatus
    func delete(_ query: CFDictionary) -> OSStatus
}
