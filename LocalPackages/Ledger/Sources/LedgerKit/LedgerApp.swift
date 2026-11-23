import Foundation

public struct LedgerApp: Equatable, Sendable {
    public let name: String

    public init(name: String) {
        self.name = name
    }

    public static let ton = LedgerApp(name: "TON")
    public static let ethereum = LedgerApp(name: "Ethereum")
    public static let tron = LedgerApp(name: "Tron")
    public static let solana = LedgerApp(name: "Solana")
    public static let bitcoin = LedgerApp(name: "Bitcoin")
}

public struct LedgerAppInfo: Equatable, Sendable {
    public let name: String
    public let version: String

    var isDashboard: Bool {
        name == "BOLOS" || name == "OLOS"
    }

    static func parse(_ reply: Data) throws -> LedgerAppInfo {
        let bytes = [UInt8](reply)
        guard bytes.count >= 3, bytes[0] == 0x01 else {
            throw LedgerTransportError.invalidResponse
        }
        let nameEnd = 2 + Int(bytes[1])
        guard bytes.count > nameEnd, bytes.count >= nameEnd + 1 + Int(bytes[nameEnd]) else {
            throw LedgerTransportError.invalidResponse
        }
        let name = String(decoding: bytes[2 ..< nameEnd], as: UTF8.self)
            .trimmingCharacters(in: CharacterSet(charactersIn: " \0"))
        let version = String(decoding: bytes[nameEnd + 1 ..< nameEnd + 1 + Int(bytes[nameEnd])], as: UTF8.self)
        return LedgerAppInfo(name: name, version: version)
    }
}

public extension LedgerLink {
    /// Moves the device one step towards `app` and returns the app's version once it is open.
    ///
    /// `nil` means poll again: the Ledger is locked or busy, or it was just asked to quit the open app
    /// or to open `app`. Either request may drop the link, after which the caller reconnects. Throws
    /// `LedgerStatusError` when the app is not installed or the user refuses to open it.
    func open(_ app: LedgerApp) async throws -> String? {
        let current: LedgerAppInfo
        do {
            current = try await LedgerAppInfo.parse(send(cla: 0xB0, ins: 0x01, timeout: 10))
        } catch let error as LedgerStatusError where error.isLocked || error.isBusy {
            return nil
        }
        if current.name == app.name {
            return current.version
        }
        if current.isDashboard {
            _ = try await send(cla: 0xE0, ins: 0xD8, data: Data(app.name.utf8))
        } else {
            _ = try await send(cla: 0xB0, ins: 0xA7, timeout: 10)
        }
        return nil
    }
}
