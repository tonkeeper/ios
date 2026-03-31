import Foundation

public struct Transaction {
    public struct RawData {
        public let refBlockBytes: String
        public let refBlockHash: String
        public var expiration: Int64
        public let feeLimit: Int?
        public let timestamp: Int64
        public let contract: Any?
    }

    public let isVisible: Bool?
    public let txID: String
    public let rawDataHex: String
    public var rawData: RawData
    public var signature: String?

    public init?(json: [String: Any]) {
        guard let txID = json["txID"] as? String,
              let rawDataHex = json["raw_data_hex"] as? String,
              let rawData = json["raw_data"] as? [String: Any],
              let refBlockBytes = rawData["ref_block_bytes"] as? String,
              let refBlockHash = rawData["ref_block_hash"] as? String,
              let expiration = rawData["expiration"] as? Int64,
              let timestamp = rawData["timestamp"] as? Int64
        else {
            return nil
        }

        self.txID = txID
        self.rawDataHex = rawDataHex
        self.rawData = RawData(
            refBlockBytes: refBlockBytes,
            refBlockHash: refBlockHash,
            expiration: expiration,
            feeLimit: rawData["fee_limit"] as? Int,
            timestamp: timestamp,
            contract: rawData["contract"]
        )
        self.signature = (json["signature"] as? [String])?.first
        self.isVisible = json["visible"] as? Bool
    }

    public func toJson() -> [String: Any] {
        var json: [String: Any] = [
            "txID": txID,
            "raw_data": [
                "contract": rawData.contract,
                "ref_block_bytes": rawData.refBlockBytes,
                "ref_block_hash": rawData.refBlockHash,
                "expiration": rawData.expiration,
                "fee_limit": rawData.feeLimit,
                "timestamp": rawData.timestamp,
            ],
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
