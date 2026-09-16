import Foundation
import Security
import TKLogging

struct MnemonicsRawDataStorageKeychainCleaner {
    let keychain: SecureStorageKeychain
    let keychainQuery: (MnemonicsRawDataStorageKeychainQuery) -> [CFString: Any]
    let logger: LogDomain

    func deleteStorageArtifacts(
        serviceKeys: MnemonicsRawDataStorageServiceKeys
    ) throws(MnemonicsRepositoryV2Failure) {
        try deleteStorageArtifacts(serviceKey: serviceKeys.mnemonics)
    }

    func deleteStorageArtifacts(
        serviceKey: String
    ) throws(MnemonicsRepositoryV2Failure) {
        let query = keychainQuery(
            .removeStorageArtifacts(serviceKey: serviceKey)
        ) as CFDictionary
        let status = keychain.delete(query)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            logger.e("Failed to delete v2 mnemonics storage artifacts. status=\(status)")
            throw .securityFailure(code: status)
        }
    }
}
