import Foundation

extension TriggerConstantContractResponse {
    public enum EstimateResourcesFailure: Error {
        case energyFailed
        case transactionDataMissing
        case invalidTransactionData
    }

    var estimatedResources: (energy: Int, bandwidth: Int) {
        get throws(EstimateResourcesFailure) {
            guard result?.result == true, let energyUsed else {
                throw .energyFailed
            }
            guard let rawDataHex = transaction?.rawDataHex else {
                throw .transactionDataMissing
            }
            guard let rawData = Data(strictHex: rawDataHex) else {
                throw .invalidTransactionData
            }

            return (energy: energyUsed, bandwidth: TronApi.bandwidth(rawDataLength: rawData.count))
        }
    }
}
