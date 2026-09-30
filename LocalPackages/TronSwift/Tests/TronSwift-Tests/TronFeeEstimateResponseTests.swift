import Foundation
import Testing
@testable import TronSwift
@testable import TronSwiftAPI

struct TronFeeEstimateResponseTests {
    /// `energy_used` is the total the chain charges: under the dynamic energy model it already
    /// contains `energy_penalty` (TronGrid returns 64285 = 14650 base + 49635 penalty for a USDT
    /// transfer). Adding the penalty on top would quote several times the real fee.
    @Test
    func energyPenalty_isAlreadyIncludedInEnergyUsed() throws {
        let response = try decode(json: [
            "result": ["result": true],
            "energy_used": 64285,
            "energy_penalty": 49635,
            "transaction": ["raw_data_hex": "0a01"],
        ])

        let resources = try response.estimatedResources(feeLimit: TronApi.usdtTransferFeeLimit)
        #expect(resources.energy == 64285)
    }

    /// TRON charges `raw_data` + its field header + 67 for a signature + 64 for the largest result.
    /// The probe is 205 bytes because `triggerconstantcontract` builds it without `fee_limit`; the
    /// transfer that gets signed is 211 and the chain charged 345 for it (tx
    /// `40e45b272b25d18bfaa5eab102fb4facca0fbca7708363609e3a6ab26c822290`, `net_usage` 345).
    @Test
    func bandwidthOfARealTransfer_matchesWhatTheChainCharged() throws {
        let response = try decode(json: [
            "result": ["result": true],
            "energy_used": 1,
            "transaction": ["raw_data_hex": String(repeating: "00", count: 205)],
        ])

        let resources = try response.estimatedResources(feeLimit: TronApi.usdtTransferFeeLimit)
        #expect(resources.bandwidth == 345)
    }

    /// Below 128 bytes the length varint is one byte shorter, and the header with it.
    @Test
    func bandwidthOfAShortTransaction_dropsAHeaderByte() throws {
        let response = try decode(json: [
            "result": ["result": true],
            "energy_used": 1,
            "transaction": ["raw_data_hex": "0a0b0c"],
        ])

        // 3 (probe) + 6 (fee_limit) + 2 (header) + 64 + 67
        let resources = try response.estimatedResources(feeLimit: TronApi.usdtTransferFeeLimit)
        #expect(resources.bandwidth == 142)
    }

    /// A smaller `fee_limit` is a shorter varint, so the estimate has to measure the value the
    /// transfer will actually carry rather than assume six bytes.
    @Test
    func bandwidthFollowsTheFeeLimitVarintWidth() throws {
        let response = try decode(json: [
            "result": ["result": true],
            "energy_used": 1,
            "transaction": ["raw_data_hex": String(repeating: "00", count: 205)],
        ])

        let resources = try response.estimatedResources(feeLimit: 1)
        #expect(resources.bandwidth == 342)
    }

    /// A `fee_limit` of zero is left off the wire entirely, so the probe already has the length the
    /// signed transaction would have.
    @Test
    func aZeroFeeLimitAddsNothing() throws {
        let response = try decode(json: [
            "result": ["result": true],
            "energy_used": 1,
            "transaction": ["raw_data_hex": String(repeating: "00", count: 205)],
        ])

        let resources = try response.estimatedResources(feeLimit: 0)
        #expect(resources.bandwidth == 339)
    }

    @Test
    func failedSimulation_throwsEnergyFailed() throws {
        let response = try decode(json: [
            "result": ["result": false],
            "energy_used": 100,
            "transaction": ["raw_data_hex": "0a01"],
        ])

        #expect(throws: TriggerConstantContractResponse.EstimateResourcesFailure.energyFailed) {
            _ = try response.estimatedResources(feeLimit: TronApi.usdtTransferFeeLimit)
        }
    }
}

private extension TronFeeEstimateResponseTests {
    func decode(json: [String: Any]) throws -> TriggerConstantContractResponse {
        let data = try JSONSerialization.data(withJSONObject: json)
        return try JSONDecoder().decode(TriggerConstantContractResponse.self, from: data)
    }
}
