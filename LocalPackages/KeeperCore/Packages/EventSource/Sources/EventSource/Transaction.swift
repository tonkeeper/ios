//
//  Transaction.swift
//
//
//  Created by Grigory Serebryanyy on 25.10.2023.
//

import Foundation

extension EventSource {
    public struct Transaction: Decodable {
        public let accountId: String
        public let lt: Int64
        public let txHash: String

        enum CodingKeys: String, CodingKey {
            case accountId = "account_id"
            case lt
            case txHash = "tx_hash"
        }
    }
}
