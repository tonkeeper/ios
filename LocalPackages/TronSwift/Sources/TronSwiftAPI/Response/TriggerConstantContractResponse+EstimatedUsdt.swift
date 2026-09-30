import Foundation
import TronSwift

extension TriggerConstantContractResponse {
    public enum EstimateResourcesFailure: Error {
        case energyFailed
        case transactionDataMissing
        case invalidTransactionData
    }

    /// The probe transaction the node simulates carries no `fee_limit`, while the transaction this
    /// estimate is quoted for is built by `triggersmartcontract` with one — six bytes the chain
    /// charges for and the probe cannot show.
    func estimatedResources(feeLimit: Int) throws(EstimateResourcesFailure) -> (energy: Int, bandwidth: Int) {
        guard result?.result == true, let energyUsed else {
            throw .energyFailed
        }
        guard let rawDataHex = transaction?.rawDataHex else {
            throw .transactionDataMissing
        }
        guard let rawData = Data(strictHex: rawDataHex) else {
            throw .invalidTransactionData
        }

        let rawDataLength = rawData.count
            + TronWireSize.feeLimitFieldLength(feeLimit: UInt64(max(feeLimit, 0)))

        return (energy: energyUsed, bandwidth: TronApi.bandwidth(rawDataLength: rawDataLength))
    }
}
