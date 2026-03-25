import Foundation

public struct TriggerConstantContractResponse: Decodable {
    struct Result: Decodable {
        let result: Bool?
    }

    struct Transaction: Decodable {
        let rawDataHex: String?

        private enum CodingKeys: String, CodingKey {
            case rawDataHex = "raw_data_hex"
        }
    }

    let result: Result?
    let energyUsed: Int?
    let transaction: Transaction?

    private enum CodingKeys: String, CodingKey {
        case result
        case energyUsed = "energy_used"
        case transaction
    }
}
