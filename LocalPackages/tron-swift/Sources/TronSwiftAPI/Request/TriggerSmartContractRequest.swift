struct TriggerSmartContractRequest: Codable {
    var ownerAddress: String
    var contractAddress: String
    var functionSelector: String
    var parameter: String
    var feeLimit: Int

    enum CodingKeys: String, CodingKey {
        case ownerAddress = "owner_address"
        case contractAddress = "contract_address"
        case functionSelector = "function_selector"
        case parameter
        case feeLimit = "fee_limit"
    }
}
