#if DEBUG
    import Foundation
    import Network

    public extension LedgerTransport {
        /// A Speculos emulator behind its APDU port, so Ledger flows run in the simulator.
        static func lab(host: String, port: UInt16) -> LedgerTransport {
            let peripheral = LedgerPeripheral(id: labPeripheralID, name: "Speculos", device: .stax)
            return LedgerTransport(
                bluetoothState: { AsyncStream { $0.yield(.poweredOn) } },
                scan: { AsyncStream { $0.yield(peripheral) } },
                connect: { _ in try await connectLab(host: host, port: port) }
            )
        }
    }

    private let labPeripheralID = UUID(uuidString: "5BEC0105-1ABE-4000-8000-000000000000")!

    private func connectLab(host: String, port: UInt16) async throws -> LedgerLink {
        guard let port = NWEndpoint.Port(rawValue: port) else {
            throw LedgerTransportError.peripheralNotFound
        }
        let connection = NWConnection(host: NWEndpoint.Host(host), port: port, using: .tcp)
        let events = LabLedgerConnectionEvents()
        connection.stateUpdateHandler = { [weak connection] state in
            if events.update(state) {
                connection?.stateUpdateHandler = nil
                connection?.cancel()
            } else if case .cancelled = state {
                connection?.stateUpdateHandler = nil
            }
        }
        connection.start(queue: DispatchQueue(label: "LedgerKit.lab"))
        try await withTaskCancellationHandler {
            try await events.waitUntilConnected()
        } onCancel: {
            connection.cancel()
        }
        return LedgerLink(
            exchange: { apdu in
                try await withTaskCancellationHandler {
                    try await send(Data(withUnsafeBytes(of: UInt32(apdu.count).bigEndian) { Array($0) }) + apdu, over: connection)
                    let length = try await receive(4, from: connection).reduce(0) { $0 << 8 | Int($1) }
                    return try await receive(length + 2, from: connection)
                } onCancel: {
                    // As over Bluetooth, an exchange cut short takes the link down with it.
                    connection.cancel()
                }
            },
            disconnected: events.disconnected,
            close: { connection.cancel() }
        )
    }

    struct LabLedgerConnectionEvents: Sendable {
        let readiness: AsyncStream<Result<Void, Error>>
        let disconnected: AsyncStream<Void>

        private let connection: AsyncStream<Result<Void, Error>>.Continuation
        private let disconnection: AsyncStream<Void>.Continuation

        init() {
            (readiness, connection) = AsyncStream.makeStream(of: Result<Void, Error>.self)
            (disconnected, disconnection) = AsyncStream.makeStream(of: Void.self)
        }

        @discardableResult
        func update(_ state: NWConnection.State) -> Bool {
            // Queued callbacks can outlive a handler change. Stream termination keeps the first connection result.
            switch state {
            case .ready:
                connection.yield(.success(()))
                connection.finish()
                return false
            case .waiting:
                if case .terminated = connection.yield(.failure(LedgerTransportError.peripheralNotFound)) {
                    return false
                }
                connection.finish()
                disconnection.finish()
                return true
            case .failed:
                connection.yield(.failure(LedgerTransportError.peripheralNotFound))
                connection.finish()
                disconnection.finish()
                return true
            case .cancelled:
                connection.yield(.failure(CancellationError()))
                connection.finish()
                disconnection.finish()
                return false
            default:
                return false
            }
        }

        func waitUntilConnected() async throws {
            for await result in readiness {
                try result.get()
            }
            try Task.checkCancellation()
        }
    }

    private func send(_ data: Data, over connection: NWConnection) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            connection.send(content: data, completion: .contentProcessed { error in
                if error != nil {
                    continuation.resume(throwing: LedgerTransportError.disconnected)
                } else {
                    continuation.resume()
                }
            })
        }
    }

    private func receive(_ count: Int, from connection: NWConnection) async throws -> Data {
        try await withCheckedThrowingContinuation { continuation in
            connection.receive(minimumIncompleteLength: count, maximumLength: count) { data, _, _, error in
                if error == nil, let data, data.count == count {
                    continuation.resume(returning: data)
                } else {
                    continuation.resume(throwing: LedgerTransportError.disconnected)
                }
            }
        }
    }
#endif
