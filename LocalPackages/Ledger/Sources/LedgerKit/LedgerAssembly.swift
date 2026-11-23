import Foundation

public final class LedgerAssembly {
    private lazy var bluetoothTransport = LedgerTransport.bluetooth()

    public init() {}

    public var transport: LedgerTransport {
        #if DEBUG
            if let lab = labEndpoint {
                return .lab(host: lab.host, port: lab.port)
            }
        #endif
        return bluetoothTransport
    }
}

#if DEBUG
    private extension LedgerAssembly {
        /// Launching with `-LedgerLab 127.0.0.1:9999` sends Ledger traffic to a Speculos emulator.
        var labEndpoint: (host: String, port: UInt16)? {
            let parts = UserDefaults.standard.string(forKey: "LedgerLab")?.split(separator: ":") ?? []
            guard parts.count == 2, let port = UInt16(parts[1]) else {
                return nil
            }
            return (String(parts[0]), port)
        }
    }
#endif
