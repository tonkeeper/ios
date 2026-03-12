import CommonCrypto
import Foundation

extension UUID {
    enum NamespaceV5 {
        static var versionValue: Int = 5
    }

    enum NamespaceV5InitFailure: Error {
        case invalidNamespace
    }

    /// https://www.reddit.com/r/swift/comments/87b3sg/is_it_possible_to_create_a_namebased_uuid_in_swift/
    init(
        namespace: String,
        name: String
    ) throws(NamespaceV5InitFailure) {
        guard let namespaceUuid = UUID(uuidString: namespace) else {
            throw .invalidNamespace
        }
        var namespaceUuidBytes = namespaceUuid.uuid
        let namespaceUuidBytesSize = MemoryLayout.size(ofValue: namespaceUuidBytes)
        var data = withUnsafePointer(to: &namespaceUuidBytes) {
            Data(bytes: $0, count: namespaceUuidBytesSize)
        }
        data.append(contentsOf: name.utf8)

        var digest = [UInt8](
            repeating: 0,
            count: Int(CC_SHA1_DIGEST_LENGTH)
        )
        data.withUnsafeBytes { (ptr: UnsafeRawBufferPointer) in
            _ = CC_SHA1(ptr.baseAddress, CC_LONG(data.count), &digest)
        }

        // Set version bits:
        digest[6] &= 0x0F
        digest[6] |= UInt8(NamespaceV5.versionValue) << 4
        // Set variant bits:
        digest[8] &= 0x3F
        digest[8] |= 0x80

        self = NSUUID(uuidBytes: digest) as UUID
    }
}

extension UUID.NamespaceV5 {
    /// random valid UUID for future UUID generation
    static let walletWebDataSourceScope = "93976e98-fe2c-4aec-82ce-e12f743b52b6"
}
