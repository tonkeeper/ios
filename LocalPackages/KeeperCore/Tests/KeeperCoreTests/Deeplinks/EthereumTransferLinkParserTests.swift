import BigInt
@testable import KeeperCore
import XCTest

final class EthereumTransferLinkParserTests: XCTestCase {
    private let parser = EthereumTransferLinkParser()

    private let recipient = "0x8e23ee67d1332ad560396262c48ffbb01f93d052"
    private let usdt = "0xdac17f958d2ee523a2206206994597c13d831ec7"

    func testNativeTransferWithChainId() {
        let parsed = parser.parse(string: "ethereum:\(recipient)@1?value=2.014e18")

        XCTAssertEqual(
            parsed,
            Deeplink.EvmTransferData(
                recipient: recipient,
                asset: .native,
                chain: .eth,
                amount: BigUInt("2014000000000000000")
            )
        )
    }

    func testNativeTransferWithoutChainIdOrAmount() {
        let parsed = parser.parse(string: "ethereum:\(recipient)")

        XCTAssertEqual(
            parsed,
            Deeplink.EvmTransferData(
                recipient: recipient,
                asset: .native,
                chain: nil,
                amount: nil
            )
        )
    }

    func testErc20TransferCarriesContractRecipientAndAmount() {
        let parsed = parser.parse(
            string: "ethereum:\(usdt)@1/transfer?address=\(recipient)&uint256=1e6"
        )

        XCTAssertEqual(
            parsed,
            Deeplink.EvmTransferData(
                recipient: recipient,
                asset: .erc20(contract: usdt),
                chain: .eth,
                amount: BigUInt(1_000_000)
            )
        )
    }

    func testErc20TransferWithoutChainIdKeepsContract() {
        let parsed = parser.parse(string: "ethereum:\(usdt)/transfer?address=\(recipient)&uint256=5")

        XCTAssertEqual(parsed?.chain, nil)
        XCTAssertEqual(parsed?.asset, .erc20(contract: usdt))
        XCTAssertEqual(parsed?.amount, BigUInt(5))
    }

    func testErc20TransferWithoutAmountIsAccepted() {
        let parsed = parser.parse(string: "ethereum:\(usdt)@8453/transfer?address=\(recipient)")

        XCTAssertEqual(parsed?.chain, .base)
        XCTAssertNil(parsed?.amount)
    }

    func testPayPrefixIsAccepted() {
        let parsed = parser.parse(string: "ethereum:pay-\(recipient)@56?value=1e18")

        XCTAssertEqual(parsed?.chain, .bsc)
        XCTAssertEqual(parsed?.amount, BigUInt("1000000000000000000"))
    }

    func testShortSchemeIsAccepted() {
        let parsed = parser.parse(string: "eth:\(recipient)@42161?value=1")

        XCTAssertEqual(parsed?.chain, .arb)
        XCTAssertEqual(parsed?.amount, BigUInt(1))
    }

    func testSchemeIsCaseInsensitive() {
        XCTAssertNotNil(parser.parse(string: "Ethereum:\(recipient)"))
    }

    func testChecksumCasingIsPreserved() {
        let checksummed = "0xfb6916095ca1df60bb79Ce92ce3ea74c37c5d359"
        let parsed = parser.parse(string: "ethereum:\(checksummed)@1?value=1")

        XCTAssertEqual(parsed?.recipient, checksummed)
    }

    func testGasParametersAreIgnored() {
        let parsed = parser.parse(
            string: "ethereum:\(recipient)@1?value=1&gas=21000&gasLimit=21000&gasPrice=100"
        )

        XCTAssertEqual(parsed?.amount, BigUInt(1))
    }

    func testUnsupportedChainIdIsRejected() {
        XCTAssertNil(parser.parse(string: "ethereum:\(recipient)@137?value=1"))
    }

    func testUnsupportedFunctionIsRejected() {
        XCTAssertNil(parser.parse(string: "ethereum:\(usdt)@1/approve?address=\(recipient)&uint256=1"))
    }

    func testTransferWithoutRecipientParameterIsRejected() {
        XCTAssertNil(parser.parse(string: "ethereum:\(usdt)@1/transfer?uint256=1"))
    }

    func testEnsNameIsRejected() {
        XCTAssertNil(parser.parse(string: "ethereum:vitalik.eth@1?value=1"))
    }

    func testUnknownPrefixIsRejected() {
        XCTAssertNil(parser.parse(string: "ethereum:vote-\(recipient)@1"))
    }

    func testMalformedAmountRejectsWholeLink() {
        XCTAssertNil(parser.parse(string: "ethereum:\(recipient)@1?value=abc"))
        XCTAssertNil(parser.parse(string: "ethereum:\(recipient)@1?value=-1"))
    }

    func testFractionNotCoveredByExponentIsRejected() {
        XCTAssertNil(parser.parse(string: "ethereum:\(recipient)@1?value=1.5"))
        XCTAssertNil(parser.parse(string: "ethereum:\(recipient)@1?value=1.005e2"))
    }

    func testTooShortAddressIsRejected() {
        XCTAssertNil(parser.parse(string: "ethereum:0x8e23ee67d1332ad560396262c48ffbb01f93d05@1"))
    }

    func testNonEthereumSchemeIsRejected() {
        XCTAssertNil(parser.parse(string: "ton://transfer/EQD2NmD_lH5f5u1Kj3KfGyTvhZSX0Eg6qp2a5IQUKXxOG21n"))
    }
}

final class ERC681AmountTests: XCTestCase {
    func testPlainInteger() {
        XCTAssertEqual(ERC681Amount.atomicUnits(from: "1000000"), BigUInt(1_000_000))
    }

    func testScientificNotation() {
        XCTAssertEqual(ERC681Amount.atomicUnits(from: "1e6"), BigUInt(1_000_000))
        XCTAssertEqual(ERC681Amount.atomicUnits(from: "2.014e18"), BigUInt("2014000000000000000"))
        XCTAssertEqual(ERC681Amount.atomicUnits(from: "1.5E2"), BigUInt(150))
    }

    func testExponentMustCoverFractionDigits() {
        XCTAssertNil(ERC681Amount.atomicUnits(from: "1.234e2"))
        XCTAssertNil(ERC681Amount.atomicUnits(from: "0.1"))
    }

    func testLeadingPlusIsAccepted() {
        XCTAssertEqual(ERC681Amount.atomicUnits(from: "+42"), BigUInt(42))
    }

    func testNegativeIsRejected() {
        XCTAssertNil(ERC681Amount.atomicUnits(from: "-42"))
    }

    func testAbsurdExponentIsRejected() {
        XCTAssertNil(ERC681Amount.atomicUnits(from: "1e1000000"))
    }

    func testNonAsciiDigitsAreRejected() {
        XCTAssertNil(ERC681Amount.atomicUnits(from: "١٢٣"))
    }

    func testEmptyIsRejected() {
        XCTAssertNil(ERC681Amount.atomicUnits(from: ""))
        XCTAssertNil(ERC681Amount.atomicUnits(from: "e18"))
    }
}
