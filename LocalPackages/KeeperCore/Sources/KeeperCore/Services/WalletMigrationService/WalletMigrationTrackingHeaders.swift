import Foundation

/// Headers attached to TON migration broadcast requests (`POST …/blockchain/message` and battery
/// `POST …/message`). TRON migration is intentionally not tracked and must not re-use these values.
enum WalletMigrationTrackingHeaders {
    static let migrationID = "X-Migration-ID"
    static let migrationFee = "X-Migration-Fee"

    enum Fee: String {
        case native
        case battery
    }

    /// One UUID (v7) per TON migration run; shared by every external message of that batch.
    static func make(
        fee: Fee,
        migrationID: String? = nil
    ) -> [String: String] {
        [
            Self.migrationID: migrationID ?? UUIDV7.string(),
            migrationFee: fee.rawValue,
        ]
    }
}

extension WalletMigrationPrepareResult.FeeMethod {
    var trackingFee: WalletMigrationTrackingHeaders.Fee {
        switch self {
        case .ton:
            return .native
        case .battery:
            return .battery
        }
    }
}

/// RFC 9562 UUID version 7 (Unix-ms timestamp + random).
enum UUIDV7 {
    static func string() -> String {
        uuid().uuidString.lowercased()
    }

    static func uuid() -> UUID {
        var bytes = [UInt8](repeating: 0, count: 16)
        let millis = UInt64(Date().timeIntervalSince1970 * 1000)
        bytes[0] = UInt8((millis >> 40) & 0xFF)
        bytes[1] = UInt8((millis >> 32) & 0xFF)
        bytes[2] = UInt8((millis >> 24) & 0xFF)
        bytes[3] = UInt8((millis >> 16) & 0xFF)
        bytes[4] = UInt8((millis >> 8) & 0xFF)
        bytes[5] = UInt8(millis & 0xFF)

        var random = [UInt8](repeating: 0, count: 10)
        var generator = SystemRandomNumberGenerator()
        for index in random.indices {
            random[index] = UInt8.random(in: .min ... .max, using: &generator)
        }
        for index in 0 ..< 10 {
            bytes[6 + index] = random[index]
        }

        // version (4 bits) = 0111
        bytes[6] = (bytes[6] & 0x0F) | 0x70
        // variant (2 bits) = 10
        bytes[8] = (bytes[8] & 0x3F) | 0x80

        return UUID(uuid: (
            bytes[0], bytes[1], bytes[2], bytes[3],
            bytes[4], bytes[5], bytes[6], bytes[7],
            bytes[8], bytes[9], bytes[10], bytes[11],
            bytes[12], bytes[13], bytes[14], bytes[15]
        ))
    }
}
