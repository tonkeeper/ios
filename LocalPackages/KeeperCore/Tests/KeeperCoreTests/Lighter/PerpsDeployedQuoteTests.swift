@testable import KeeperCore
import TKPerpsAPI
import XCTest

final class PerpsDeployedQuoteTests: XCTestCase {
    private static let sender = "0x7ECebAF27c989adEF9EA3DD06D316F6F463a5109"

    /// Captured from production on 2026-09-23; `operation.type` dropped and `preview` added as the
    /// 2026-10 spec has them.
    private static let deployedDirectQuote = """
    {"created_at":"2026-09-23T12:02:22.772091816Z","expires_at":"2026-09-23T12:02:52.772091816Z",\
    "input":{"address":"0x7ECebAF27c989adEF9EA3DD06D316F6F463a5109","amount":"1000000",\
    "asset_id":"eth/mainnet/erc20/0xa0b86991c6218b36c1d19d4a2e9eb0ce3606eb48"},\
    "operation":{"id":"e929a294-4ba9-4a93-99a1-11ae271c49fb","payloads":[\
    {"chain_id":"eth/mainnet","id":"p_01","meta":{"data":"0x095ea7b30000000000000000000000003b4d794a66304f130a4db8f2551b0070dfcf5ca700000000000000000000000000000000000000000000000000000000000f4240",\
    "to":"0xa0b86991c6218b36c1d19d4a2e9eb0ce3606eb48","value":"0"},"type":"main","version":1},\
    {"chain_id":"eth/mainnet","id":"p_02","meta":{"data":"0x8a8570830000000000000000000000007ecebaf27c989adef9ea3dd06d316f6f463a51090000000000000000000000000000000000000000000000000000000000000003000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000f4240",\
    "to":"0x3b4d794a66304f130a4db8f2551b0070dfcf5ca7","value":"0"},"type":"main","version":1}]},\
    "output":{"address":"0x7ecebaf27c989adef9ea3dd06d316f6f463a5109","amount":"1000000",\
    "asset_id":"eth/mainnet/erc20/0xa0b86991c6218b36c1d19d4a2e9eb0ce3606eb48","min_amount":"1000000"},\
    "preview":false,"provider":"direct","quote_id":"q_c5aa61d8ff5614239130c27d9581d2ea"}
    """

    func testTheDeployedShapeIsReadAsASpecQuoteWithItsApproveFirst() throws {
        let quote = try decode(Data(Self.deployedDirectQuote.utf8))

        let read = try PerpsDepositQuoteReader.read(
            quote,
            request: request,
            now: quote.expires_at.addingTimeInterval(-10)
        )

        XCTAssertEqual(read.route, .directGateway)
        XCTAssertEqual(read.payloads.map(\.kind), [.approval, .main])
        XCTAssertEqual(read.payloads.map(\.payloadId), ["p_01", "p_02"])
        XCTAssertEqual(read.payloads.last?.to, "0x3b4d794a66304f130a4db8f2551b0070dfcf5ca7")
    }

    func testAnApproveOfAnotherTokenIsNotTakenForTheDepositsApproval() throws {
        let quote = try decode(Data(Self.deployedDirectQuote
                .replacingOccurrences(
                    of: "\"to\":\"0xa0b86991c6218b36c1d19d4a2e9eb0ce3606eb48\"",
                    with: "\"to\":\"0xdac17f958d2ee523a2206206994597c13d831ec7\""
                ).utf8))

        let read = try PerpsDepositQuoteReader.read(quote, request: request, now: quote.expires_at.addingTimeInterval(-10))

        XCTAssertEqual(read.payloads.map(\.kind), [.main, .main])
    }

    func testAPayloadOfAnUnknownVersionIsRefused() throws {
        let quote = try decode(Data(Self.deployedDirectQuote
                .replacingOccurrences(of: "\"version\":1}]}", with: "\"version\":2}]}").utf8))

        XCTAssertThrowsError(
            try PerpsDepositQuoteReader.read(quote, request: request, now: quote.expires_at.addingTimeInterval(-10))
        ) { error in
            XCTAssertEqual(error as? PerpsDepositQuoteError, .malformedOperation(quote.operation.id))
        }
    }

    private var request: Components.Schemas.DepositQuoteRequest {
        .init(
            source_asset: PerpsFundingAssetId.usdcEthereum,
            source_amount: "1000000",
            sender_address: Self.sender,
            destination_address: Self.sender
        )
    }

    private func decode(_ data: Data) throws -> Components.Schemas.DepositQuote {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            try MultichainDateTranscoder().decode(decoder.singleValueContainer().decode(String.self))
        }
        return try decoder.decode(Components.Schemas.DepositQuote.self, from: data)
    }
}
