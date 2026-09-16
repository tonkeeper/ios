import Foundation
import TKLogging
import TonSwift

enum TonMessageHash {
    enum Failure: Error, LoggableError {
        case undecodableBase64
        case emptyBoc
        case undeserializableBoc(underlying: any Error)

        var logDescription: String {
            switch self {
            case .undecodableBase64:
                return "type=TonMessageHash.Failure, case=undecodableBase64"
            case .emptyBoc:
                return "type=TonMessageHash.Failure, case=emptyBoc"
            case .undeserializableBoc:
                return "type=TonMessageHash.Failure, case=undeserializableBoc"
            }
        }
    }

    static func hex(signedBocBase64: String) throws(Failure) -> String {
        guard let data = Data(base64Encoded: signedBocBase64) else {
            throw .undecodableBase64
        }
        let cells: [Cell]
        do {
            cells = try Cell.fromBoc(src: data)
        } catch {
            throw .undeserializableBoc(underlying: error)
        }
        guard let root = cells.first else {
            throw .emptyBoc
        }
        return root.representationHash().hexString()
    }
}
