import BigInt
@testable import KeeperCore
import XCTest

final class SolanaTransferLinkParserTests: XCTestCase {
    private let parser = SolanaTransferLinkParser()

    private let recipient = "HLT1cw2FTfgMJ2DNZHQpcr19n5bqrfqBGxEuFSEWgE4r"
    private let usdcMint = "EPjFWdd5AufqSSqeM2qN1xzybapC8G4wEGGkZwyTDt1v"
    private let reference = "82ZJ7nbGpixjeDCmEhUcmwXYfvurzAgGdtSMuHnUgyny"

    func testNativeTransferWithAmount() {
        XCTAssertEqual(
            parser.parse(string: "solana:\(recipient)?amount=0.001"),
            Deeplink.SolanaTransferData(
                recipient: recipient,
                asset: .native,
                amount: Deeplink.DecimalAmount("0.001")
            )
        )
    }

    func testNativeTransferWithoutAmount() {
        XCTAssertEqual(
            parser.parse(string: "solana:\(recipient)"),
            Deeplink.SolanaTransferData(recipient: recipient, asset: .native, amount: nil)
        )
    }

    func testSplTokenTransferKeepsMintCasing() {
        let parsed = parser.parse(string: "solana:\(recipient)?amount=1.5&spl-token=\(usdcMint)")

        XCTAssertEqual(parsed?.asset, .splToken(mint: usdcMint))
        XCTAssertEqual(parsed?.asset.assetId, "sol/mainnet/spl/\(usdcMint)")
        XCTAssertEqual(parsed?.amount?.atomicUnits(decimals: 6), BigUInt(1_500_000))
    }

    func testNativeAssetIsTheCoin() {
        XCTAssertEqual(Deeplink.SolanaTransferData.Asset.native.assetId, "sol/mainnet/coin")
    }

    func testDisplayOnlyParametersAreIgnored() {
        let parsed = parser.parse(
            string: "solana:\(recipient)?amount=1&label=Michael&message=Thanks%20for%20all%20the%20fish"
        )

        XCTAssertEqual(parsed?.amount, Deeplink.DecimalAmount("1"))
    }

    func testSchemeIsCaseInsensitiveAndWhitespaceIsTrimmed() {
        XCTAssertEqual(parser.parse(string: " SOLANA:\(recipient)\n")?.recipient, recipient)
    }

    func testReferenceIsRejected() {
        XCTAssertNil(parser.parse(string: "solana:\(recipient)?amount=1&reference=\(reference)"))
        XCTAssertNil(parser.parse(string: "solana:\(recipient)?amount=1&reference"))
    }

    func testMemoIsRejected() {
        XCTAssertNil(parser.parse(string: "solana:\(recipient)?amount=1&memo=OrderId12345"))
    }

    func testEmptyMemoIsNoMemo() {
        XCTAssertEqual(parser.parse(string: "solana:\(recipient)?amount=1&memo=")?.recipient, recipient)
    }

    func testTransactionRequestIsRejected() {
        XCTAssertNil(parser.parse(string: "solana:https://example.com/solana-pay"))
        XCTAssertNil(parser.parse(string: "solana:https%3A%2F%2Fexample.com%2Fsolana-pay%3Forder%3D12345"))
    }

    func testInvalidRecipientIsRejected() {
        XCTAssertNil(parser.parse(string: "solana:"))
        XCTAssertNil(parser.parse(string: "solana:\(recipient.prefix(20))?amount=1"))
        XCTAssertNil(parser.parse(string: "solana:\(recipient)0?amount=1"))
        XCTAssertNil(parser.parse(string: "solana:TR7NHqjeKQxGTCi8q8ZY4pL8otSzgjLj6t"))
        XCTAssertNil(parser.parse(string: "solana:0x8e23ee67d1332ad560396262c48ffbb01f93d052"))
    }

    func testInvalidSplTokenIsRejected() {
        XCTAssertNil(parser.parse(string: "solana:\(recipient)?spl-token=USDC"))
        XCTAssertNil(parser.parse(string: "solana:\(recipient)?spl-token="))
    }

    func testMalformedAmountIsRejected() {
        for amount in ["", ".5", "-1", "+1", "1e3", "1,5", "1.2.3", "abc", "0x10", "1%2000"] {
            XCTAssertNil(parser.parse(string: "solana:\(recipient)?amount=\(amount)"), amount)
        }
    }

    func testFirstAmountWins() {
        XCTAssertEqual(
            parser.parse(string: "solana:\(recipient)?amount=1&amount=2")?.amount,
            Deeplink.DecimalAmount("1")
        )
    }

    func testOtherPayloadsAreIgnored() {
        XCTAssertNil(parser.parse(string: recipient))
        XCTAssertNil(parser.parse(string: "ethereum:0x8e23ee67d1332ad560396262c48ffbb01f93d052"))
        XCTAssertNil(parser.parse(string: "ton://transfer/\(recipient)"))
    }

    func testDecimalAmountConvertsToAtomicUnits() throws {
        XCTAssertEqual(try XCTUnwrap(Deeplink.DecimalAmount("0.001")).atomicUnits(decimals: 9), BigUInt(1_000_000))
        XCTAssertEqual(try XCTUnwrap(Deeplink.DecimalAmount("12")).atomicUnits(decimals: 6), BigUInt(12_000_000))
        XCTAssertEqual(try XCTUnwrap(Deeplink.DecimalAmount("1.")).atomicUnits(decimals: 2), BigUInt(100))
        XCTAssertEqual(try XCTUnwrap(Deeplink.DecimalAmount("007.5")).atomicUnits(decimals: 1), BigUInt(75))
    }

    func testDecimalAmountFinerThanDecimalsHasNoAtomicValue() throws {
        XCTAssertNil(try XCTUnwrap(Deeplink.DecimalAmount("0.0000000001")).atomicUnits(decimals: 9))
        XCTAssertNil(try XCTUnwrap(Deeplink.DecimalAmount("1.0000001")).atomicUnits(decimals: 6))
    }

    func testDecimalAmountIgnoresTrailingFractionZeros() throws {
        XCTAssertEqual(Deeplink.DecimalAmount("1.500000000000"), Deeplink.DecimalAmount("1.5"))
        XCTAssertEqual(try XCTUnwrap(Deeplink.DecimalAmount("1.500000000000")).atomicUnits(decimals: 6), BigUInt(1_500_000))
    }
}
