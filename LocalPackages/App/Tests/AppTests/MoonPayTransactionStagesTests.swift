import MoonPay
import XCTest

final class MoonPayTransactionStagesTests: XCTestCase {
    func test_authenticationStage_isTheWaitingAuthenticationOne() throws {
        let json = #"""
        {
            "id":"tx_1","status":"pending",
            "stages":[
                {"kind":"ordering","name":"Ordering","status":"success","failureReason":null},
                {"kind":"waiting_authentication","name":"Authentication","status":"in_progress","failureReason":null}
            ]
        }
        """#
        let details = try JSONDecoder().decode(MoonPayTransactionDetails.self, from: Data(json.utf8))

        XCTAssertEqual(details.authenticationStage?.status, "in_progress")
    }

    func test_authenticationStage_isNil_withoutOne() throws {
        let json = #"{"id":"tx_1","status":"pending","stages":[{"kind":"ordering","status":"success"}]}"#
        let details = try JSONDecoder().decode(MoonPayTransactionDetails.self, from: Data(json.utf8))

        XCTAssertNil(details.authenticationStage)
    }
}
