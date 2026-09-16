@preconcurrency import AnyCodable
import Foundation

extension AnyCodable {
    var walletConnectObjectValue: [String: Any]? {
        if let value = value as? [String: Any] {
            return value
        }
        if let value = value as? [String: AnyCodable] {
            return value.mapValues(\.value)
        }
        return nil
    }
}
