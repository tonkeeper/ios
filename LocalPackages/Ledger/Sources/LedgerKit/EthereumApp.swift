import Foundation

public enum EthereumApp {
    public struct Account: Equatable, Sendable {
        /// Uncompressed secp256k1 key, `04 ‖ X ‖ Y`.
        public let publicKey: Data
        /// As the device reports it: lowercase hex without `0x`.
        public let address: String
    }

    /// `m/44'/60'/account'/0/0`, the path Ledger Live uses.
    public static func path(account: Int) -> Data {
        LedgerPath.data([44 | LedgerPath.hardened, 60 | LedgerPath.hardened, UInt32(account) | LedgerPath.hardened, 0, 0])
    }

    static func account(reply: Data) throws -> Account {
        let bytes = [UInt8](reply)
        guard bytes.count >= 67, bytes[0] == 65, bytes.count >= 67 + Int(bytes[66]) else {
            throw LedgerTransportError.invalidResponse
        }
        let address = String(decoding: bytes[67 ..< 67 + Int(bytes[66])], as: UTF8.self).lowercased()
        return Account(
            publicKey: Data(bytes[1 ..< 66]),
            address: address.hasPrefix("0x") ? String(address.dropFirst(2)) : address
        )
    }

    /// `path ‖ transaction` cut into `e0 04` payloads. The app cannot finish a legacy transaction whose
    /// last chunk is no longer than its `chainId, 0, 0` trailer, so legacy chunks are sized to avoid that.
    static func signChunks(path: Data, transaction: Data, chainId: UInt64) -> [Data] {
        let payload = [UInt8](path + transaction)
        let isLegacy = (transaction.first ?? 0) >= 0xC0
        let trailer = rlpLength(chainId) + 2
        let size = isLegacy
            ? stride(from: 255, through: path.count + 1, by: -1).first { payload.count % $0 == 0 || payload.count % $0 > trailer } ?? 255
            : 255
        return stride(from: 0, to: payload.count, by: size).map { Data(payload[$0 ..< min($0 + size, payload.count)]) }
    }

    /// The device's `v ‖ r ‖ s` as wallet-core wants it: `r ‖ s ‖ parity`.
    static func signature(reply: Data, transaction: Data, chainId: UInt64) throws -> Data {
        let bytes = [UInt8](reply)
        guard bytes.count >= 65 else {
            throw LedgerTransportError.invalidResponse
        }
        let isLegacy = (transaction.first ?? 0) >= 0xC0
        let parity = isLegacy ? legacyParity(v: bytes[0], chainId: chainId) : bytes[0] & 1
        return Data(bytes[1 ..< 65] + [parity])
    }

    /// A legacy `v` is `chainId * 2 + 35 + parity`, truncated by the app to its last byte.
    static func legacyParity(v: UInt8, chainId: UInt64) -> UInt8 {
        let excessBytes = max(0, 64 - chainId.leadingZeroBitCount - 32 + 7) / 8
        return UInt8(truncatingIfNeeded: (chainId >> (8 * excessBytes)) * 2 + 35) == v ? 0 : 1
    }

    static func rlpLength(_ value: UInt64) -> Int {
        value <= 0x7F ? 1 : 1 + (64 - value.leadingZeroBitCount + 7) / 8
    }

    /// `path ‖ length ‖ message` cut into `e0 08` payloads.
    static func messageChunks(path: Data, message: Data) -> [Data] {
        let payload = [UInt8](path + withUnsafeBytes(of: UInt32(message.count).bigEndian) { Data($0) } + message)
        return stride(from: 0, to: payload.count, by: 255).map { Data(payload[$0 ..< min($0 + 255, payload.count)]) }
    }

    /// The device's `v ‖ r ‖ s` for a message as dApps take it: `r ‖ s ‖ v`, with `v` 27 or 28.
    static func messageSignature(reply: Data) throws -> Data {
        let bytes = [UInt8](reply)
        guard bytes.count >= 65 else {
            throw LedgerTransportError.invalidResponse
        }
        return Data(bytes[1 ..< 65] + [bytes[0] < 27 ? bytes[0] + 27 : bytes[0]])
    }
}

public extension LedgerLink {
    func ethereumAccount(path: Data, display: Bool = false, chainId: UInt64? = nil) async throws -> EthereumApp.Account {
        let chain = display ? chainId.map { Data(withUnsafeBytes(of: $0.bigEndian, Array.init)) } ?? Data() : Data()
        let reply = try await send(cla: 0xE0, ins: 0x02, p1: display ? 0x01 : 0x00, data: path + chain, timeout: display ? nil : 10)
        return try EthereumApp.account(reply: reply)
    }

    /// Returns `r ‖ s ‖ parity` for `transaction`, the unsigned transaction wallet-core hands out as the
    /// pre-image (`rlp(...)` for legacy, `0x02 ‖ rlp(...)` for EIP-1559).
    func signEthereumTransaction(_ transaction: Data, path: Data, chainId: UInt64) async throws -> Data {
        var reply = Data()
        for (index, chunk) in EthereumApp.signChunks(path: path, transaction: transaction, chainId: chainId).enumerated() {
            reply = try await send(cla: 0xE0, ins: 0x04, p1: index == 0 ? 0x00 : 0x80, data: chunk)
        }
        return try EthereumApp.signature(reply: reply, transaction: transaction, chainId: chainId)
    }

    /// Hands the app Ledger's signed token descriptor so it shows the token and amount instead of raw data.
    func provideEthereumToken(descriptor: Data, signature: Data) async throws {
        let tickerLength = descriptor.count - 28
        guard (1 ... 32).contains(tickerLength) else {
            throw LedgerTransportError.invalidRequest
        }
        _ = try await send(cla: 0xE0, ins: 0x0A, data: Data([UInt8(tickerLength)]) + descriptor + signature, timeout: 10)
    }

    /// Signs `message` as `personal_sign` does, behind `"\u{19}Ethereum Signed Message:\n" ‖ length`, and returns
    /// `r ‖ s ‖ v`.
    func signEthereumPersonalMessage(_ message: Data, path: Data) async throws -> Data {
        var reply = Data()
        for (index, chunk) in EthereumApp.messageChunks(path: path, message: message).enumerated() {
            reply = try await send(cla: 0xE0, ins: 0x08, p1: index == 0 ? 0x00 : 0x80, data: chunk)
        }
        return try EthereumApp.messageSignature(reply: reply)
    }

    /// Signs EIP-712 data by its domain separator and message hash and returns `r ‖ s ‖ v`. The app shows only the
    /// hashes, so it asks for blind signing.
    func signEthereumTypedDataHashes(domainSeparator: Data, messageHash: Data, path: Data) async throws -> Data {
        guard domainSeparator.count == 32, messageHash.count == 32 else {
            throw LedgerTransportError.invalidRequest
        }
        return try await EthereumApp.messageSignature(reply: send(cla: 0xE0, ins: 0x0C, data: path + domainSeparator + messageHash))
    }

    func ethereumBlindSigningEnabled() async throws -> Bool {
        let reply = try await send(cla: 0xE0, ins: 0x06, timeout: 10)
        guard let flags = reply.first else {
            throw LedgerTransportError.invalidResponse
        }
        return flags & 0x01 != 0
    }
}
