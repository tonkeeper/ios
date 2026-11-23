import Foundation

public struct LedgerStatusError: Error, Equatable {
    public let statusWord: UInt16

    public init(statusWord: UInt16) {
        self.statusWord = statusWord
    }

    public var isLocked: Bool {
        [0x5515, 0x6B0C, 0x5303, 0x6982].contains(statusWord)
    }

    public var isBusy: Bool {
        statusWord == 0x6901
    }

    public var isRefused: Bool {
        statusWord == 0x6985 || statusWord == 0x5501
    }

    public var isAppMissing: Bool {
        statusWord == 0x6807 || statusWord == 0x6984
    }

    public var isInvalidData: Bool {
        statusWord == 0x6A80
    }
}

public extension LedgerLink {
    /// Sends one APDU and returns its reply without the status word, which must be 0x9000.
    func send(
        cla: UInt8,
        ins: UInt8,
        p1: UInt8 = 0x00,
        p2: UInt8 = 0x00,
        data: Data = Data(),
        timeout: TimeInterval? = nil
    ) async throws -> Data {
        guard data.count <= 255 else {
            throw LedgerTransportError.invalidRequest
        }
        let apdu = Data([cla, ins, p1, p2, UInt8(data.count)]) + data
        let response = if let timeout {
            try await exchange(apdu, timeout: timeout)
        } else {
            try await exchange(apdu)
        }
        let reply = [UInt8](response)
        guard reply.count >= 2 else {
            throw LedgerTransportError.invalidResponse
        }
        let statusWord = UInt16(reply[reply.count - 2]) << 8 | UInt16(reply[reply.count - 1])
        guard statusWord == 0x9000 else {
            throw LedgerStatusError(statusWord: statusWord)
        }
        return Data(reply.dropLast(2))
    }

    /// Fails with `LedgerTransportError.timeout` when the device does not answer in time; the link is
    /// closed then, as a late reply could not be told apart from the next one.
    func exchange(_ apdu: Data, timeout: TimeInterval) async throws -> Data {
        try await withThrowingTaskGroup(of: Data.self) { group in
            group.addTask { try await exchange(apdu) }
            group.addTask {
                try await Task.sleep(nanoseconds: UInt64(timeout * 1_000_000_000))
                close()
                throw LedgerTransportError.timeout
            }
            defer { group.cancelAll() }
            guard let reply = try await group.next() else {
                throw LedgerTransportError.invalidResponse
            }
            return reply
        }
    }
}
