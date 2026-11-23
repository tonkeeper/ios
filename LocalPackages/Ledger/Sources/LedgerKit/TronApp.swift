import CryptoKit
import Foundation

public enum TronApp {
    public struct Account: Equatable, Sendable {
        /// Uncompressed secp256k1 key, `04 ‖ X ‖ Y`.
        public let publicKey: Data
        /// Base58check, as the device reports it.
        public let address: String
    }

    /// A setting the app has to have on for a transaction it answered with the status word.
    public enum Setting: Equatable, Sendable {
        case transactionsData
        case customContracts
        case signByHash

        public init?(_ error: LedgerStatusError) {
            switch error.statusWord {
            case 0x6A8B:
                self = .transactionsData
            case 0x6A8C:
                self = .signByHash
            case 0x6A8D:
                self = .customContracts
            default:
                return nil
            }
        }
    }

    /// `m/44'/195'/account'/0/0`, the path Ledger Live uses.
    public static func path(account: Int) -> Data {
        LedgerPath.data([44 | LedgerPath.hardened, 195 | LedgerPath.hardened, UInt32(account) | LedgerPath.hardened, 0, 0])
    }

    static let chunkLimit = 250

    static func account(reply: Data) throws -> Account {
        let bytes = [UInt8](reply)
        guard bytes.count >= 67, bytes[0] == 65, bytes.count >= 67 + Int(bytes[66]) else {
            throw LedgerTransportError.invalidResponse
        }
        return Account(publicKey: Data(bytes[1 ..< 66]), address: String(decoding: bytes[67 ..< 67 + Int(bytes[66])], as: UTF8.self))
    }

    /// `path ‖ rawData` cut into `e0 04` payloads. The app parses each payload on its own, so a payload
    /// holds whole protobuf fields; `nil` when a field does not fit one and only the hash can be signed.
    static func signChunks(path: Data, rawData: Data) throws -> [Data]? {
        let bytes = [UInt8](rawData)
        let fields = try fieldRanges(of: bytes)
        guard fields.allSatisfy({ $0.count <= chunkLimit }) else {
            return nil
        }
        return fields.reduce(into: [path]) { chunks, field in
            if chunks[chunks.endIndex - 1].count + field.count > chunkLimit {
                chunks.append(Data())
            }
            chunks[chunks.endIndex - 1] += bytes[field]
        }
    }

    static func signP1(index: Int, count: Int) -> UInt8 {
        switch index {
        case _ where count == 1:
            0x10
        case 0:
            0x00
        case count - 1:
            0x90
        default:
            0x80
        }
    }

    static func signature(reply: Data) throws -> Data {
        guard reply.count >= 65 else {
            throw LedgerTransportError.invalidResponse
        }
        return Data(reply.prefix(65))
    }

    /// `path ‖ length ‖ message` cut into `e0 08` payloads; the path rides in the first one.
    static func messageChunks(path: Data, message: Data) -> [Data] {
        let packed = [UInt8](withUnsafeBytes(of: UInt32(message.count).bigEndian) { Data($0) } + message)
        let first = min(packed.count, chunkLimit - path.count)
        return [path + Data(packed[0 ..< first])]
            + stride(from: first, to: packed.count, by: chunkLimit).map { Data(packed[$0 ..< min($0 + chunkLimit, packed.count)]) }
    }

    static func fieldRanges(of bytes: [UInt8]) throws -> [Range<Int>] {
        var ranges: [Range<Int>] = []
        var offset = 0
        while offset < bytes.count {
            let start = offset
            switch try varint(bytes, at: &offset) & 0x07 {
            case 0:
                _ = try varint(bytes, at: &offset)
            case 1:
                offset += 8
            case 2:
                let length = try varint(bytes, at: &offset)
                guard length <= UInt64(bytes.count - offset) else {
                    throw LedgerTransportError.invalidRequest
                }
                offset += Int(length)
            case 5:
                offset += 4
            default:
                throw LedgerTransportError.invalidRequest
            }
            guard offset <= bytes.count else {
                throw LedgerTransportError.invalidRequest
            }
            ranges.append(start ..< offset)
        }
        return ranges
    }

    private static func varint(_ bytes: [UInt8], at offset: inout Int) throws -> UInt64 {
        var value: UInt64 = 0
        for shift in stride(from: 0, to: 64, by: 7) {
            guard offset < bytes.count else {
                throw LedgerTransportError.invalidRequest
            }
            let byte = bytes[offset]
            offset += 1
            value |= UInt64(byte & 0x7F) << UInt64(shift)
            if byte & 0x80 == 0 {
                return value
            }
        }
        throw LedgerTransportError.invalidRequest
    }
}

public extension LedgerLink {
    func tronAccount(path: Data, display: Bool = false) async throws -> TronApp.Account {
        try await TronApp.account(reply: send(cla: 0xE0, ins: 0x02, p1: display ? 0x01 : 0x00, data: path, timeout: display ? nil : 10))
    }

    /// Signs `rawData`, a transaction's protobuf `raw_data`, and returns `r ‖ s ‖ v`. A transaction with a
    /// field longer than a payload is signed by its hash, which the app allows only with that setting on.
    func signTronTransaction(_ rawData: Data, path: Data) async throws -> Data {
        guard let chunks = try TronApp.signChunks(path: path, rawData: rawData) else {
            return try await TronApp.signature(reply: send(cla: 0xE0, ins: 0x05, data: path + Data(SHA256.hash(data: rawData))))
        }
        var reply = Data()
        for (index, chunk) in chunks.enumerated() {
            reply = try await send(cla: 0xE0, ins: 0x04, p1: TronApp.signP1(index: index, count: chunks.count), data: chunk)
        }
        return try TronApp.signature(reply: reply)
    }

    /// Signs `message` as TronWeb's `signMessageV2` does, behind `"\u{19}TRON Signed Message:\n" ‖ length`, and
    /// returns `r ‖ s ‖ v` with `v` 27 or 28.
    func signTronPersonalMessage(_ message: Data, path: Data) async throws -> Data {
        var reply = Data()
        for (index, chunk) in TronApp.messageChunks(path: path, message: message).enumerated() {
            reply = try await send(cla: 0xE0, ins: 0x08, p1: index == 0 ? 0x00 : 0x80, data: chunk)
        }
        let signature = try [UInt8](TronApp.signature(reply: reply))
        return Data(signature[0 ..< 64] + [signature[64] < 27 ? signature[64] + 27 : signature[64]])
    }
}
