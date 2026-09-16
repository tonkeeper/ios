import Foundation

public struct Transaction {
    public struct RawData {
        /// The node's own `raw_data` object, kept verbatim. The signature is taken over
        /// `raw_data_hex` while the battery relay broadcasts from this JSON, so the two have to
        /// describe the same transaction: a field rebuilt here — or dropped because this type does
        /// not know it — would be signed as one transaction and broadcast as another.
        public let json: [String: Any]
        public var expiration: Int64

        public var contract: Any? {
            json["contract"]
        }
    }

    public var isVisible: Bool?
    public let txID: String
    public let rawDataHex: String
    public var rawData: RawData
    public var signature: String?

    init(
        isVisible: Bool?,
        txID: String,
        rawDataHex: String,
        rawData: RawData,
        signature: String?
    ) {
        self.isVisible = isVisible
        self.txID = txID
        self.rawDataHex = rawDataHex
        self.rawData = rawData
        self.signature = signature
    }

    public init?(json: [String: Any]) {
        guard let txID = json["txID"] as? String,
              let rawDataHex = json["raw_data_hex"] as? String,
              let rawData = json["raw_data"] as? [String: Any],
              rawData["ref_block_bytes"] is String,
              rawData["ref_block_hash"] is String,
              let expiration = rawData["expiration"] as? Int64,
              rawData["timestamp"] is Int64
        else {
            return nil
        }

        self.txID = txID
        self.rawDataHex = rawDataHex
        self.rawData = RawData(json: rawData, expiration: expiration)
        self.signature = (json["signature"] as? [String])?.first
        self.isVisible = json["visible"] as? Bool
    }

    public func toJson() -> [String: Any] {
        var rawDataJson = rawData.json
        rawDataJson["expiration"] = rawData.expiration

        var json: [String: Any] = [
            "txID": txID,
            "raw_data": rawDataJson,
            "raw_data_hex": rawDataHex,
        ]

        if let signature {
            json["signature"] = [signature]
        }
        if let isVisible {
            json["visible"] = isVisible
        }

        return json
    }
}
