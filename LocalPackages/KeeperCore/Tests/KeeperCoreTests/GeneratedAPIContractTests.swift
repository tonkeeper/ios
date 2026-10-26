import Foundation
@testable import KeeperCore
import MultichainAPI
import TKBatteryAPI
import TKPerpsAPI
import TKTradingAPI
import XCTest

final class GeneratedAPIContractTests: XCTestCase {
    func test_unknownMultichainStatusDecodesAndIsDroppedByTheMapper() throws {
        let data = Data(#"""
        {"activity_type":"send","status":"future-status","block_time":0,"block_number":0,
         "from_chain":"ton","to_chain":"ton","wallet_address":"wallet","direction":"out",
         "from_address":"from","to_address":"to","tx_ids":[],"is_read":false}
        """#.utf8)
        let activity = try JSONDecoder().decode(MultichainAPI.Components.Schemas.Activity.self, from: data)

        XCTAssertEqual(activity.status, .unknown)
        XCTAssertNil(MultichainActivity(api: activity))
        XCTAssertEqual(
            try JSONDecoder().decode(MultichainAPI.Components.Schemas.ActivityDirection.self, from: Data(#""future-direction""#.utf8)),
            .unknown
        )
    }

    func test_capabilitiesPreserveValuesMissingFromTheSpec() throws {
        let data = Data(#"""
        {"asset_id":"ton/mainnet/coin","name":"Toncoin","symbol":"TON","decimals":9,
         "image":"","verification":"trusted","capabilities":{"capabilities":["swap","perp_deposit","future-capability"]}}
        """#.utf8)
        let asset = try JSONDecoder().decode(MultichainAPI.Components.Schemas.AssetInfo.self, from: data)

        XCTAssertEqual(MultichainAssetDetails(api: asset).capabilities, [.swap, .perpDeposit])
    }

    func test_tradingUnknownCapabilityDoesNotFailDecoding() throws {
        XCTAssertEqual(
            try JSONDecoder().decode(TKTradingAPI.Components.Schemas.AssetCapability.self, from: Data(#""future-capability""#.utf8)),
            .unknown
        )
    }

    func test_numericSignatureParityKeepsItsWireTypeAndRejectsUnknownValues() throws {
        typealias Parity = TKBatteryAPI.Components.Schemas.EvmSignedAuthorization.y_parityPayload
        XCTAssertEqual(try JSONDecoder().decode(Parity.self, from: Data("1".utf8)), ._1)
        XCTAssertEqual(try JSONEncoder().encode(Parity._1), Data("1".utf8))
        XCTAssertThrowsError(try JSONDecoder().decode(Parity.self, from: Data("2".utf8)))
    }

    func test_perpsSigningPayloadRetainsUnknownFields() throws {
        let data = Data(#"{"type":"future/payload","meta":{"data":{"r":"0x01","y_parity":1}},"extra":[1,"keep"]}"#.utf8)
        let payload = try JSONDecoder().decode(TKPerpsAPI.Components.Schemas.QuotePayload.self, from: data)
        let encoded = try JSONEncoder().encode(payload)

        XCTAssertEqual(
            try JSONSerialization.jsonObject(with: data) as? NSDictionary,
            try JSONSerialization.jsonObject(with: encoded) as? NSDictionary
        )
    }
}
