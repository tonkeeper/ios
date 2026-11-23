import CoreBluetooth
import Foundation

public extension LedgerTransport {
    static func bluetooth() -> LedgerTransport {
        let central = BluetoothLedgerCentral()
        return LedgerTransport(
            bluetoothState: { central.states() },
            scan: { central.scan() },
            connect: { try await central.connect(to: $0) }
        )
    }
}

private let ledgerServices = LedgerDevice.bluetoothDevices.flatMap(\.bluetoothSpec)
private let ledgerServiceUUIDs = ledgerServices.map { CBUUID(string: $0.serviceUuid) }

/// Stored properties are touched only on `queue`, the queue CoreBluetooth calls the delegate on.
private final class BluetoothLedgerCentral: NSObject, CBCentralManagerDelegate, @unchecked Sendable {
    private let queue = DispatchQueue(label: "LedgerKit.bluetooth")
    private var manager: CBCentralManager?
    private var stateObservers: [UUID: AsyncStream<CBManagerState>.Continuation] = [:]
    private var scanObserver: (id: UUID, continuation: AsyncStream<LedgerPeripheral>.Continuation)?
    private var links: [UUID: BluetoothLedgerLink] = [:]

    private var central: CBCentralManager {
        if let manager {
            return manager
        }
        let manager = CBCentralManager(delegate: self, queue: queue)
        self.manager = manager
        return manager
    }

    func states() -> AsyncStream<CBManagerState> {
        AsyncStream { continuation in
            let id = UUID()
            continuation.onTermination = { _ in
                self.queue.async { self.stateObservers[id] = nil }
            }
            queue.async {
                self.stateObservers[id] = continuation
                continuation.yield(self.central.state)
            }
        }
    }

    func scan() -> AsyncStream<LedgerPeripheral> {
        AsyncStream { continuation in
            let id = UUID()
            continuation.onTermination = { _ in
                self.queue.async {
                    guard self.scanObserver?.id == id else {
                        return
                    }
                    self.scanObserver = nil
                    self.manager?.stopScan()
                }
            }
            queue.async {
                self.scanObserver?.continuation.finish()
                self.scanObserver = (id, continuation)
                self.scanIfPossible()
            }
        }
    }

    func connect(to id: UUID) async throws -> LedgerLink {
        try Task.checkCancellation()
        let link = try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                queue.async { self.open(id, continuation: continuation) }
            }
        } onCancel: {
            queue.async { self.links[id]?.fail(CancellationError()) }
        }
        return link.ledgerLink
    }

    private func open(_ id: UUID, continuation: CheckedContinuation<BluetoothLedgerLink, Error>) {
        let central = central
        guard central.state == .poweredOn else {
            continuation.resume(throwing: LedgerTransportError.bluetoothUnavailable)
            return
        }
        guard let peripheral = central.retrievePeripherals(withIdentifiers: [id]).first else {
            continuation.resume(throwing: LedgerTransportError.peripheralNotFound)
            return
        }
        links[id]?.fail(LedgerTransportError.disconnected)
        links[id] = BluetoothLedgerLink(peripheral: peripheral, queue: queue, opening: continuation) {
            central.cancelPeripheralConnection(peripheral)
        }
        central.connect(peripheral)
    }

    private func scanIfPossible() {
        guard scanObserver != nil, central.state == .poweredOn else {
            return
        }
        central.scanForPeripherals(withServices: ledgerServiceUUIDs)
    }

    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        stateObservers.values.forEach { $0.yield(central.state) }
        guard central.state == .poweredOn else {
            links.values.forEach { $0.fail(LedgerTransportError.bluetoothUnavailable) }
            links.removeAll()
            return
        }
        scanIfPossible()
    }

    func centralManager(
        _: CBCentralManager,
        didDiscover peripheral: CBPeripheral,
        advertisementData: [String: Any],
        rssi _: NSNumber
    ) {
        let advertised = advertisementData[CBAdvertisementDataServiceUUIDsKey] as? [CBUUID] ?? []
        guard let service = advertised.first(where: ledgerServiceUUIDs.contains) else {
            return
        }
        let device = LedgerDevice.getDeviceWith(serviceUUID: service)
        scanObserver?.continuation.yield(
            LedgerPeripheral(id: peripheral.identifier, name: peripheral.name ?? device.productName, device: device)
        )
    }

    func centralManager(_: CBCentralManager, didConnect peripheral: CBPeripheral) {
        links[peripheral.identifier]?.didConnect()
    }

    func centralManager(_: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        links.removeValue(forKey: peripheral.identifier)?.fail(LedgerTransportError.fromBluetooth(error))
    }

    func centralManager(_: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        guard let link = links[peripheral.identifier], link.didDisconnect(error) else {
            return
        }
        links[peripheral.identifier] = nil
    }
}

/// Stored properties are touched only on `queue`, the queue CoreBluetooth calls the delegate on.
private final class BluetoothLedgerLink: NSObject, CBPeripheralDelegate, @unchecked Sendable {
    private typealias Opening = CheckedContinuation<BluetoothLedgerLink, Error>
    private typealias Exchange = CheckedContinuation<Data, Error>

    private struct Channel {
        let write: CBCharacteristic
        let frameSize: Int
    }

    private enum Phase {
        case connecting(Opening)
        case discovering(Opening)
        case subscribing(Opening, write: CBCharacteristic)
        case negotiating(Opening, write: CBCharacteristic)
        case ready(Channel)
        case exchanging(Channel, frames: ArraySlice<Data>, assembly: LedgerFrameAssembly, Exchange)
        case closed
    }

    private let peripheral: CBPeripheral
    private let queue: DispatchQueue
    private let cancelConnection: () -> Void
    private let disconnected: AsyncStream<Void>
    private let disconnection: AsyncStream<Void>.Continuation
    private var phase: Phase

    init(
        peripheral: CBPeripheral,
        queue: DispatchQueue,
        opening: CheckedContinuation<BluetoothLedgerLink, Error>,
        cancelConnection: @escaping () -> Void
    ) {
        self.peripheral = peripheral
        self.queue = queue
        self.cancelConnection = cancelConnection
        (disconnected, disconnection) = AsyncStream.makeStream(of: Void.self)
        phase = .connecting(opening)
    }

    var ledgerLink: LedgerLink {
        LedgerLink(
            exchange: { try await self.exchange($0) },
            disconnected: disconnected,
            close: { self.queue.async { self.fail(LedgerTransportError.disconnected) } }
        )
    }

    func didConnect() {
        guard case let .connecting(opening) = phase else {
            return
        }
        phase = .discovering(opening)
        peripheral.delegate = self
        peripheral.discoverServices(ledgerServiceUUIDs)
    }

    /// Returns `false` for a disconnection that belongs to the connection this link replaced.
    func didDisconnect(_ error: Error?) -> Bool {
        if case .connecting = phase {
            return false
        }
        fail(LedgerTransportError.fromBluetooth(error))
        return true
    }

    func fail(_ error: Error) {
        switch phase {
        case let .connecting(opening), let .discovering(opening), let .subscribing(opening, _), let .negotiating(opening, _):
            opening.resume(throwing: error)
        case let .exchanging(_, _, _, exchange):
            exchange.resume(throwing: error)
        case .ready:
            break
        case .closed:
            return
        }
        phase = .closed
        disconnection.finish()
        cancelConnection()
    }

    private func exchange(_ apdu: Data) async throws -> Data {
        try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                queue.async { self.send(apdu, continuation: continuation) }
            }
        } onCancel: {
            queue.async { self.fail(CancellationError()) }
        }
    }

    private func send(_ apdu: Data, continuation: Exchange) {
        switch phase {
        case let .ready(channel):
            let frames = LedgerFraming.frames(of: apdu, frameSize: channel.frameSize)
            phase = .exchanging(channel, frames: frames.dropFirst(), assembly: .empty, continuation)
            peripheral.writeValue(frames[0], for: channel.write, type: .withResponse)
        case .closed:
            continuation.resume(throwing: LedgerTransportError.disconnected)
        default:
            continuation.resume(throwing: LedgerTransportError.busy)
        }
    }

    private func finishNegotiation(reply: Data?) {
        guard case let .negotiating(opening, write) = phase else {
            return
        }
        let frameSize = reply.flatMap(LedgerFraming.frameSize(mtuReply:))
            ?? peripheral.maximumWriteValueLength(for: .withoutResponse)
        phase = .ready(Channel(write: write, frameSize: frameSize))
        opening.resume(returning: self)
    }

    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        guard case .discovering = phase else {
            return
        }
        guard let service = peripheral.services?.first(where: { ledgerServiceUUIDs.contains($0.uuid) }) else {
            fail(LedgerTransportError.fromBluetooth(error))
            return
        }
        peripheral.discoverCharacteristics(nil, for: service)
    }

    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        guard case let .discovering(opening) = phase else {
            return
        }
        let characteristic = { (uuid: String) in
            service.characteristics?.first { $0.uuid == CBUUID(string: uuid) }
        }
        guard let spec = ledgerServices.first(where: { CBUUID(string: $0.serviceUuid) == service.uuid }),
              let notify = characteristic(spec.notifyUuid),
              let write = characteristic(spec.writeUuid)
        else {
            fail(LedgerTransportError.fromBluetooth(error))
            return
        }
        phase = .subscribing(opening, write: write)
        peripheral.setNotifyValue(true, for: notify)
    }

    func peripheral(_ peripheral: CBPeripheral, didUpdateNotificationStateFor _: CBCharacteristic, error: Error?) {
        guard case let .subscribing(opening, write) = phase else {
            return
        }
        if let error {
            fail(LedgerTransportError.fromBluetooth(error))
            return
        }
        phase = .negotiating(opening, write: write)
        peripheral.writeValue(LedgerFraming.mtuRequest, for: write, type: .withResponse)
        queue.asyncAfter(deadline: .now() + 3) { self.finishNegotiation(reply: nil) }
    }

    func peripheral(_ peripheral: CBPeripheral, didWriteValueFor _: CBCharacteristic, error: Error?) {
        if let error {
            fail(LedgerTransportError.fromBluetooth(error))
            return
        }
        guard case let .exchanging(channel, frames, assembly, exchange) = phase, let frame = frames.first else {
            return
        }
        phase = .exchanging(channel, frames: frames.dropFirst(), assembly: assembly, exchange)
        peripheral.writeValue(frame, for: channel.write, type: .withResponse)
    }

    func peripheral(_: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        if let error {
            fail(LedgerTransportError.fromBluetooth(error))
            return
        }
        guard let value = characteristic.value else {
            return
        }
        switch phase {
        case .negotiating:
            finishNegotiation(reply: value)
        case let .exchanging(channel, frames, assembly, exchange):
            do {
                let assembly = try assembly.appending(value)
                if let response = assembly.response {
                    phase = .ready(channel)
                    exchange.resume(returning: response)
                } else {
                    phase = .exchanging(channel, frames: frames, assembly: assembly, exchange)
                }
            } catch {
                fail(error)
            }
        default:
            break
        }
    }
}
