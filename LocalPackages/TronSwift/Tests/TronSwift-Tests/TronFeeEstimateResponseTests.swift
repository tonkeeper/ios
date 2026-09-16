import Foundation
import Testing
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

        let resources = try response.estimatedResources
        #expect(resources.energy == 64285)
    }

    /// TRON charges `raw_data` + its field header + 67 for a signature + 64 for the largest result.
    /// A real TRC20 transfer is 211 bytes of `raw_data`, whose length needs a two-byte varint, so
    /// the header is three bytes.
    @Test
    func bandwidthOfARealTransfer_matchesTheProtocolFormula() throws {
        let response = try decode(json: [
            "result": ["result": true],
            "energy_used": 1,
            "transaction": ["raw_data_hex": String(repeating: "00", count: 211)],
        ])

        let resources = try response.estimatedResources
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

        let resources = try response.estimatedResources
        #expect(resources.bandwidth == 136)
    }

    @Test
    func failedSimulation_throwsEnergyFailed() throws {
        let response = try decode(json: [
            "result": ["result": false],
            "energy_used": 100,
            "transaction": ["raw_data_hex": "0a01"],
        ])

        #expect(throws: TriggerConstantContractResponse.EstimateResourcesFailure.energyFailed) {
            _ = try response.estimatedResources
        }
    }
}

private extension TronFeeEstimateResponseTests {
    func decode(json: [String: Any]) throws -> TriggerConstantContractResponse {
        let data = try JSONSerialization.data(withJSONObject: json)
        return try JSONDecoder().decode(TriggerConstantContractResponse.self, from: data)
    }
}
