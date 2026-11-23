import Foundation

/// A BIP-32 path as the device apps take it: the number of indices, then each index big-endian.
enum LedgerPath {
    static let hardened: UInt32 = 0x8000_0000

    static func data(_ indices: [UInt32]) -> Data {
        Data([UInt8(indices.count)] + indices.flatMap { withUnsafeBytes(of: $0.bigEndian, Array.init) })
    }
}
