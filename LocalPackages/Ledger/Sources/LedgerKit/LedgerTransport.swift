import CoreBluetooth
import Foundation

public struct LedgerTransport: Sendable {
    public let bluetoothState: @Sendable () -> AsyncStream<CBManagerState>
    /// Yields Ledgers as they are found; scanning stops when the stream is no longer iterated.
    public let scan: @Sendable () -> AsyncStream<LedgerPeripheral>
    public let connect: @Sendable (_ peripheralID: UUID) async throws -> LedgerLink

    public init(
        bluetoothState: @escaping @Sendable () -> AsyncStream<CBManagerState>,
        scan: @escaping @Sendable () -> AsyncStream<LedgerPeripheral>,
        connect: @escaping @Sendable (_ peripheralID: UUID) async throws -> LedgerLink
    ) {
        self.bluetoothState = bluetoothState
        self.scan = scan
        self.connect = connect
    }
}

public struct LedgerPeripheral: Sendable {
    public let id: UUID
    public let name: String
    public let device: LedgerDevice

    public init(id: UUID, name: String, device: LedgerDevice) {
        self.id = id
        self.name = name
        self.device = device
    }
}

public struct LedgerLink: Sendable {
    /// Sends a raw APDU and returns the device's raw reply, status word included.
    public let exchange: @Sendable (_ apdu: Data) async throws -> Data
    /// Finishes once the link is down.
    public let disconnected: AsyncStream<Void>
    public let close: @Sendable () -> Void

    public init(
        exchange: @escaping @Sendable (_ apdu: Data) async throws -> Data,
        disconnected: AsyncStream<Void>,
        close: @escaping @Sendable () -> Void
    ) {
        self.exchange = exchange
        self.disconnected = disconnected
        self.close = close
    }
}
