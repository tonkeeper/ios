import Foundation

enum TransferSignaturePrefixedHash {
    private static let l2TLId: Int32 = 0x71B3_4EE1

    static func prefixedHash(prefixId: Int32, hash: Data) -> Data {
        var input = Data(count: 8)
        input[0] = UInt8(truncatingIfNeeded: l2TLId)
        input[1] = UInt8(truncatingIfNeeded: l2TLId >> 8)
        input[2] = UInt8(truncatingIfNeeded: l2TLId >> 16)
        input[3] = UInt8(truncatingIfNeeded: l2TLId >> 24)
        input[4] = UInt8(truncatingIfNeeded: prefixId)
        input[5] = UInt8(truncatingIfNeeded: prefixId >> 8)
        input[6] = UInt8(truncatingIfNeeded: prefixId >> 16)
        input[7] = UInt8(truncatingIfNeeded: prefixId >> 24)
        return input.sha256() + hash
    }
}
