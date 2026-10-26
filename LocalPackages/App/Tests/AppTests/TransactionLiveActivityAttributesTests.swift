@testable import App
import Foundation
import XCTest

@available(iOS 16.2, *)
final class TransactionLiveActivityAttributesTests: XCTestCase {
    typealias Attributes = TransactionLiveActivityAttributes

    func test_legacyContentUsesTheIdentityFromItsAttributes() throws {
        let attributes = try legacyAttributes()
        let content = try JSONDecoder().decode(Attributes.ContentState.self, from: Data(
            """
            {"status":"pending","title":"Sending","updatedAt":123,
             "source":{"network":"TON","currency":"TON","amount":"10"},"kind":"send"}
            """.utf8
        ))

        let resolved = attributes.resolving(content)

        XCTAssertEqual(resolved.transactionId, "ton:legacy")
        XCTAssertEqual(resolved.chain, "ton")
        XCTAssertEqual(resolved.detail, "TON")
        XCTAssertEqual(resolved.status, .pending)
        XCTAssertEqual(resolved.title, "Sending")
        XCTAssertEqual(resolved.source?.amount, "10")
        XCTAssertEqual(resolved.updatedAt, Date(timeIntervalSinceReferenceDate: 123))
    }

    func test_newContentRoundTripsAndOverridesTheLegacyIdentityAfterHandoff() throws {
        let attributes = try legacyAttributes()
        let state = Attributes.ContentState(
            transactionId: "perps-funding:new",
            chain: "eth",
            detail: nil,
            status: .confirmed,
            title: "Deposited",
            updatedAt: Date(timeIntervalSinceReferenceDate: 456),
            source: nil,
            destination: .init(network: "ETH", currency: "USDC", amount: "25"),
            kind: .receive,
            wallet: .init(name: "Wallet", emoji: "👛", icon: nil),
            counterpartyAddress: "counterparty",
            stage: .init(index: 4, count: 4),
            perpsMarketId: 1
        )

        let decoded = try JSONDecoder().decode(Attributes.ContentState.self, from: JSONEncoder().encode(state))

        XCTAssertEqual(decoded, state)
        XCTAssertEqual(attributes.resolving(decoded), state)
        XCTAssertNil(attributes.resolving(decoded).detail)
    }

    func test_newAttributesOnlyEncodeTheWalletIdentity() throws {
        let data = try JSONEncoder().encode(Attributes(walletId: "wallet"))
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: String])

        XCTAssertEqual(object, ["walletId": "wallet"])
        XCTAssertEqual(try JSONDecoder().decode(Attributes.self, from: data).walletId, "wallet")
    }

    private func legacyAttributes() throws -> Attributes {
        try JSONDecoder().decode(Attributes.self, from: Data(
            """
            {"walletId":"wallet","transactionId":"ton:legacy","chain":"ton","detail":"TON"}
            """.utf8
        ))
    }
}
