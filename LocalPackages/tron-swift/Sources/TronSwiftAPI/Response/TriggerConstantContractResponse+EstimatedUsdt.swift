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
            let DATA_HEX_PROTOBUF_EXTRA = 9
            let MAX_RESULT_SIZE_IN_TX = 64
            let A_SIGNATURE = 67

            guard let rawData = Data(hex: rawDataHex) else {
                throw .invalidTransactionData
            }

            let bandwidth: Int = rawData.count
                + DATA_HEX_PROTOBUF_EXTRA
                + MAX_RESULT_SIZE_IN_TX
                + A_SIGNATURE

            return (energy: energyUsed, bandwidth: bandwidth)
        }
    }
}
