import Foundation

struct MultichainRealtimeEnvelope: Decodable, Equatable {
    let version: Int
    let event: String
    let walletId: String
    let seq: Int64

    enum CodingKeys: String, CodingKey {
        case version = "v"
        case event
        case walletId = "wallet_id"
        case seq
    }
}

protocol MultichainRealtimeEventHandler: AnyObject {
    func accept(_ envelope: MultichainRealtimeEnvelope, payload: Data) -> Bool
}

struct MultichainRealtimeSeqFilter {
    private var applied = [String: Int64]()

    mutating func isNew(_ seq: Int64, key: String) -> Bool {
        if let previous = applied[key], seq <= previous {
            return false
        }
        applied[key] = seq
        return true
    }
}
