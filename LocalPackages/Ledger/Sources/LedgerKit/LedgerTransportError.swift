import CoreBluetooth
import Foundation

public enum LedgerTransportError: Error {
    case bluetoothUnavailable
    case bluetoothUnsupported
    case peripheralNotFound
    /// The Ledger no longer has this phone's pairing; it has to be forgotten in iOS Bluetooth settings.
    case pairingRemoved
    case disconnected
    case busy
    case timeout
    case invalidRequest
    case invalidResponse
}

extension LedgerTransportError {
    static func fromBluetooth(_ error: Error?) -> Error {
        guard let error else {
            return LedgerTransportError.disconnected
        }
        guard let bluetoothError = error as? CBError else {
            return error
        }
        switch bluetoothError.code {
        case .connectionTimeout, .encryptionTimedOut:
            return LedgerTransportError.timeout
        case .notConnected, .peripheralDisconnected, .connectionFailed:
            return LedgerTransportError.disconnected
        case .peerRemovedPairingInformation:
            return LedgerTransportError.pairingRemoved
        default:
            return error
        }
    }
}
