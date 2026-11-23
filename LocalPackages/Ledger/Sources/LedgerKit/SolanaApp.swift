import Foundation

public enum SolanaApp {
    /// `m/44'/501'/account'/0'`, the path Ledger Live uses.
    public static func path(account: Int) -> Data {
        LedgerPath.data([44 | LedgerPath.hardened, 501 | LedgerPath.hardened, UInt32(account) | LedgerPath.hardened, LedgerPath.hardened])
    }

    /// The app answers a transaction it can show only with blind signing on with this status.
    public static func requiresBlindSigning(_ error: LedgerStatusError) -> Bool {
        error.statusWord == 0x6808
    }

    static func publicKey(reply: Data) throws -> Data {
        guard reply.count >= 32 else {
            throw LedgerTransportError.invalidResponse
        }
        return Data(reply.prefix(32))
    }

    /// `1 ‖ path ‖ message`, one signer and what it signs, cut into `e0 06` payloads.
    static func signChunks(path: Data, message: Data) -> [Data] {
        let payload = [UInt8]([1]) + path + message
        return stride(from: 0, to: payload.count, by: 255).map { Data(payload[$0 ..< min($0 + 255, payload.count)]) }
    }

    /// `0x01` extends what the previous payload started, `0x02` says more follows.
    static func signP2(index: Int, count: Int) -> UInt8 {
        (index > 0 ? 0x01 : 0x00) | (index < count - 1 ? 0x02 : 0x00)
    }

    static func signature(reply: Data) throws -> Data {
        guard reply.count >= 64 else {
            throw LedgerTransportError.invalidResponse
        }
        return Data(reply.prefix(64))
    }
}

public extension LedgerLink {
    /// The ed25519 key of `path`; with `display` the device shows its address for the user to confirm.
    func solanaPublicKey(path: Data, display: Bool = false) async throws -> Data {
        try await SolanaApp.publicKey(reply: send(cla: 0xE0, ins: 0x05, p1: display ? 0x01 : 0x00, data: path, timeout: display ? nil : 10))
    }

    /// Signs a transaction's message and returns the ed25519 signature.
    func signSolanaMessage(_ message: Data, path: Data) async throws -> Data {
        let chunks = SolanaApp.signChunks(path: path, message: message)
        var reply = Data()
        for (index, chunk) in chunks.enumerated() {
            reply = try await send(cla: 0xE0, ins: 0x06, p1: 0x01, p2: SolanaApp.signP2(index: index, count: chunks.count), data: chunk)
        }
        return try SolanaApp.signature(reply: reply)
    }
}
