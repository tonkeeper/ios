import Foundation
@testable import KeeperCore
import TonSwift
import XCTest

final class RatesCodingTests: XCTestCase {
    func test_rateKeepsEveryDigitThroughARoundTrip() throws {
        let rate = try Rates.Rate(
            currency: .USD,
            rate: XCTUnwrap(Decimal(string: "0.000042064567593002")),
            diff24h: "+2.87%"
        )

        let decoded = try JSONDecoder().decode(
            Rates.Rate.self,
            from: JSONEncoder().encode(rate)
        )

        XCTAssertEqual(decoded.rate, rate.rate)
        XCTAssertEqual(decoded.currency, rate.currency)
        XCTAssertEqual(decoded.diff24h, rate.diff24h)
    }

    func test_rateReadsTheRoundedStringLeftByOlderBuilds() throws {
        let json = Data(#"{"currency":"USD","rate":"1.389","diff24h":"+2.87%"}"#.utf8)

        let decoded = try JSONDecoder().decode(Rates.Rate.self, from: json)

        XCTAssertEqual(decoded.rate, Decimal(string: "1.389"))
    }

    func test_rateReadsANumber() throws {
        let json = Data(#"{"currency":"USD","rate":1.3887222}"#.utf8)

        let decoded = try JSONDecoder().decode(Rates.Rate.self, from: json)

        XCTAssertEqual(decoded.rate, Decimal(string: "1.3887222"))
        XCTAssertNil(decoded.diff24h)
    }

    func test_rateReadsANumberWithoutMaterializingItsBinaryApproximation() throws {
        let json = Data(#"{"currency":"USD","rate":0.1}"#.utf8)

        let decoded = try JSONDecoder().decode(Rates.Rate.self, from: json)

        XCTAssertEqual(decoded.rate, Decimal(string: "0.1"))
    }

    func test_jettonBalanceKeepsItsRatesThroughARoundTrip() throws {
        let price = try XCTUnwrap(Decimal(string: "0.0001970304146"))
        let balance = try JettonBalance(
            item: JettonItem(jettonInfo: .hmstrStub(), walletAddress: nil),
            quantity: 1_990_201_381_131,
            rates: [.USD: Rates.Rate(currency: .USD, rate: price, diff24h: nil)]
        )

        let decoded = try JSONDecoder().decode(
            JettonBalance.self,
            from: JSONEncoder().encode(balance)
        )

        XCTAssertEqual(decoded.rates[.USD]?.rate, price)
    }
}

private extension JettonInfo {
    static func hmstrStub() throws -> JettonInfo {
        try JettonInfo(
            isTransferable: true,
            hasCustomPayload: false,
            address: Address.parse("0:0000000000000000000000000000000000000000000000000000000000000000"),
            fractionDigits: 9,
            name: "Hamster Kombat",
            symbol: "HMSTR",
            verification: .whitelist,
            imageURL: nil
        )
    }
}
