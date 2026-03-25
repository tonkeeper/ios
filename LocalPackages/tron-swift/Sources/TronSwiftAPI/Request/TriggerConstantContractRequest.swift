import Foundation

struct TriggerConstantContractRequest: Encodable {
    let ownerAddress: String
    let contractAddress: String
    let functionSelector: String
    let parameter: String
    let visible: Bool

    private enum CodingKeys: String, CodingKey {
        case ownerAddress = "owner_address"
        case contractAddress = "contract_address"
        case functionSelector = "function_selector"
        case parameter
        case visible
    }
}
