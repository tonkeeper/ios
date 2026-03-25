import Foundation

enum ValidatedReceipt: Decodable {
    case success(purchases: [InAppPurchase])
    case failed(statusCode: Int)

    enum CodingKeys: String, CodingKey {
        case status
        case receipt
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let status = try container.decode(Int.self, forKey: .status)
        if status == 0 {
            let receipt = try container.decode(Receipt.self, forKey: .receipt)
            self = .success(purchases: receipt.inAppPurchases)
        } else {
            self = .failed(statusCode: status)
        }
    }
}

extension ValidatedReceipt {
    struct Receipt: Decodable {
        enum CodingKeys: String, CodingKey {
            case inAppPurchases = "in_app"
        }

        let inAppPurchases: [InAppPurchase]
    }

    struct InAppPurchase: Decodable {
        enum OwnershipType: String, Decodable {
            case purchased = "PURCHASED"
            case familyShared = "FAMILY_SHARED"
        }

        enum CodingKeys: String, CodingKey {
            case originalTransactionId = "original_transaction_id"
            case ownershipType = "in_app_ownership_type"
        }

        let originalTransactionId: String
        let ownershipType: OwnershipType
    }
}
