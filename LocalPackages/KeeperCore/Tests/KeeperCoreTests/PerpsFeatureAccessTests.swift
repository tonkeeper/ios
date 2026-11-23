import Foundation
@testable import KeeperCore
import PerpsModels
import XCTest

final class PerpsFeatureAccessTests: XCTestCase {
    func testTheStateComesFromFeatureAccess() throws {
        for access in [PerpsAccess.available, .restricted, .hidden] {
            let json = #"{"flags": {"perps_enabled": true}, "feature_access": {"perps": {"state": "\#(access.rawValue)", "reason": "region"}}}"#
            XCTAssertEqual(try perpsAccess(json), access)
        }
    }

    func testWithoutFeatureAccessTheLegacyFlagDecides() throws {
        XCTAssertEqual(try perpsAccess(#"{"flags": {"perps_enabled": true}}"#), .available)
        XCTAssertEqual(try perpsAccess(#"{"flags": {"perps_enabled": true}, "feature_access": null}"#), .available)
        XCTAssertEqual(try perpsAccess(#"{"flags": {"perps_enabled": false}}"#), .hidden)
        XCTAssertEqual(try perpsAccess("{}"), .hidden)
    }

    func testAnUnknownOrMalformedFeatureAccessHidesPerps() throws {
        for featureAccess in [
            "{}",
            #"{"perps": {}}"#,
            #"{"perps": {"state": "beta"}}"#,
            #""off""#,
        ] {
            let json = #"{"flags": {"perps_enabled": true}, "feature_access": \#(featureAccess)}"#
            XCTAssertEqual(try perpsAccess(json), .hidden, json)
        }
    }

    func testACachedConfigurationKeepsItsState() throws {
        for json in [
            #"{"flags": {"perps_enabled": true}, "feature_access": {"perps": {"state": "beta"}}}"#,
            #"{"flags": {"perps_enabled": true}}"#,
            #"{"flags": {"perps_enabled": true}, "feature_access": null}"#,
        ] {
            let decoded = try JSONDecoder().decode(BootConfiguration.self, from: Data(json.utf8))
            let cached = try JSONDecoder().decode(BootConfiguration.self, from: JSONEncoder().encode(decoded))
            XCTAssertEqual(cached.perpsAccess, decoded.perpsAccess, json)
        }
    }

    private func perpsAccess(_ json: String) throws -> PerpsAccess {
        try JSONDecoder().decode(BootConfiguration.self, from: Data(json.utf8)).perpsAccess
    }
}
