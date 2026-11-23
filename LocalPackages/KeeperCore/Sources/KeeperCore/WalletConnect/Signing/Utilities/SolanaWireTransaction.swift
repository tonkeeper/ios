import Foundation

/// A serialized Solana transaction: its signatures and the message they sign.
struct SolanaWireTransaction: Equatable {
    enum Failure: Error, Equatable {
        case malformed
        case notASigner
    }

    private(set) var signatures: [Data]
    let message: Data
    /// The keys whose signatures the message needs, in the order of `signatures`.
    let signers: [Data]

    init(_ bytes: Data) throws {
        var reader = Reader(bytes: [UInt8](bytes))
        let count = try reader.shortVec()
        signatures = try (0 ..< count).map { _ in try Data(reader.read(64)) }
        message = Data(bytes.dropFirst(reader.offset))
        var messageReader = Reader(bytes: [UInt8](message))
        if try messageReader.peek() & 0x80 != 0 {
            _ = try messageReader.read(1)
        }
        let header = try messageReader.read(3)
        let keyCount = try messageReader.shortVec()
        guard Int(header[0]) == count, count <= keyCount else {
            throw Failure.malformed
        }
        signers = try (0 ..< count).map { _ in try Data(messageReader.read(32)) }
    }

    mutating func sign(_ signature: Data, by key: Data) throws {
        guard signature.count == 64, let index = signers.firstIndex(of: key) else {
            throw Failure.notASigner
        }
        signatures[index] = signature
    }

    var serialized: Data {
        Self.shortVec(signatures.count) + signatures.reduce(Data(), +) + message
    }

    static func shortVec(_ value: Int) -> Data {
        var bytes = [UInt8]()
        var rest = value
        repeat {
            let byte = UInt8(rest & 0x7F)
            rest >>= 7
            bytes.append(rest == 0 ? byte : byte | 0x80)
        } while rest != 0
        return Data(bytes)
    }
}

private struct Reader {
    let bytes: [UInt8]
    private(set) var offset = 0

    func peek() throws -> UInt8 {
        guard offset < bytes.count else {
            throw SolanaWireTransaction.Failure.malformed
        }
        return bytes[offset]
    }

    mutating func read(_ count: Int) throws -> [UInt8] {
        guard count <= bytes.count - offset else {
            throw SolanaWireTransaction.Failure.malformed
        }
        defer { offset += count }
        return Array(bytes[offset ..< offset + count])
    }

    mutating func shortVec() throws -> Int {
        var value = 0
        for shift in stride(from: 0, through: 14, by: 7) {
            let byte = try read(1)[0]
            value |= Int(byte & 0x7F) << shift
            if byte & 0x80 == 0 {
                return value
            }
        }
        throw SolanaWireTransaction.Failure.malformed
    }
}
