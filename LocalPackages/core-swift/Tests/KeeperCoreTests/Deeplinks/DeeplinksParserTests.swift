import BigInt
@testable import KeeperCore
import TonSwift
import XCTest

final class DeeplinksParserTests: XCTestCase {
    let parser = DeeplinkParser()

    func testTransferTonkeeperDeeplinkParsing() throws {
        let address = "EQD2NmD_lH5f5u1Kj3KfGyTvhZSX0Eg6qp2a5IQUKXxOG21n"
        let text = "just comment"
        let amount = "10000"

        let string = "tonkeeper://transfer/\(address)?text=\(text)&amount=\(amount)"
        let transferData = Deeplink.TransferData(
            recipient: address,
            amount: BigUInt(amount),
            comment: text,
            jettonAddress: nil,
            expirationTimestamp: nil,
            successReturn: nil
        )
        let result = Deeplink.transfer(.sendTransfer(transferData))
        let parsedDeeplink = try parser.parse(string: string)

        XCTAssertEqual(parsedDeeplink, result)
    }

    func testTransferTonDeeplinkParsing() throws {
        let address = "EQD2NmD_lH5f5u1Kj3KfGyTvhZSX0Eg6qp2a5IQUKXxOG21n"
        let text = "just comment"
        let amount = "10000"

        let string = "ton://transfer/\(address)?text=\(text)&amount=\(amount)"
        let transferData = Deeplink.TransferData(
            recipient: address,
            amount: BigUInt(amount),
            comment: text,
            jettonAddress: nil,
            expirationTimestamp: nil,
            successReturn: nil
        )
        let result = Deeplink.transfer(.sendTransfer(transferData))
        let parsedDeeplink = try parser.parse(string: string)

        XCTAssertEqual(parsedDeeplink, result)
    }

    func testTransferUniversalLinkParsing() throws {
        let address = "EQD2NmD_lH5f5u1Kj3KfGyTvhZSX0Eg6qp2a5IQUKXxOG21n"
        let text = "just comment"
        let amount = "10000"

        let string = "https://app.tonkeeper.com/transfer/\(address)?text=\(text)&amount=\(amount)"
        let transferData = Deeplink.TransferData(
            recipient: address,
            amount: BigUInt(amount),
            comment: text,
            jettonAddress: nil,
            expirationTimestamp: nil,
            successReturn: nil
        )
        let result = Deeplink.transfer(.sendTransfer(transferData))

        let parsedDeeplink = try parser.parse(string: string)

        XCTAssertEqual(parsedDeeplink, result)
    }

    func testStakingTonDeeplinkParsing() throws {
        let string = "ton://staking"
        let result = Deeplink.staking

        let parsedDeeplink = try parser.parse(string: string)

        XCTAssertEqual(parsedDeeplink, result)
    }

    func testStakingTonkeeperDeeplinkParsing() throws {
        let string = "tonkeeper://staking"
        let result = Deeplink.staking

        let parsedDeeplink = try parser.parse(string: string)

        XCTAssertEqual(parsedDeeplink, result)
    }

    func testStakingTonkeeperUniversalLinkParsing() throws {
        let string = "https://app.tonkeeper.com/staking"
        let result = Deeplink.staking

        let parsedDeeplink = try parser.parse(string: string)

        XCTAssertEqual(parsedDeeplink, result)
    }

    func testBuyTonkeeperDeeplinkParsing() throws {
        let string = "tonkeeper://buy-ton"
        let result = Deeplink.buyTon

        let parsedDeeplink = try parser.parse(string: string)

        XCTAssertEqual(parsedDeeplink, result)
    }

    func testBuyTonTonDeeplinkParsing() throws {
        let string = "ton://buy-ton"
        let result = Deeplink.buyTon

        let parsedDeeplink = try parser.parse(string: string)

        XCTAssertEqual(parsedDeeplink, result)
    }

    func testBuyTonkeeperUniversaLinkParsing() throws {
        let string = "https://app.tonkeeper.com/buy-ton"
        let result = Deeplink.buyTon

        let parsedDeeplink = try parser.parse(string: string)

        XCTAssertEqual(parsedDeeplink, result)
    }

    func testExchangeTonDeeplinkParsing() throws {
        let provider = "neocrypto"
        let string = "ton://exchange/neocrypto"
        let result = Deeplink.exchange(provider: provider)

        let parsedDeeplink = try parser.parse(string: string)

        XCTAssertEqual(parsedDeeplink, result)
    }

    func testExchangeTonkeeperDeeplinkParsing() throws {
        let provider = "neocrypto"
        let string = "tonkeeper://exchange/neocrypto"
        let result = Deeplink.exchange(provider: provider)

        let parsedDeeplink = try parser.parse(string: string)

        XCTAssertEqual(parsedDeeplink, result)
    }

    func testExchangeTonkeeperUniversalLinkParsing() throws {
        let provider = "neocrypto"
        let string = "https://app.tonkeeper.com/exchange/neocrypto"
        let result = Deeplink.exchange(provider: provider)

        let parsedDeeplink = try parser.parse(string: string)

        XCTAssertEqual(parsedDeeplink, result)
    }

    func testSwapTonDeeplinkParsing() throws {
        let string = "ton://swap?ft=TON&tt=FNZ"
        let swapData = Deeplink.SwapData(
            fromToken: "TON",
            toToken: "FNZ"
        )
        let result = Deeplink.swap(swapData)

        let parsedDeeplink = try parser.parse(string: string)

        XCTAssertEqual(parsedDeeplink, result)
    }

    func testSwapTonkeeperDeeplinkParsing() throws {
        let string = "tonkeeper://swap?ft=TON&tt=FNZ"
        let swapData = Deeplink.SwapData(
            fromToken: "TON",
            toToken: "FNZ"
        )
        let result = Deeplink.swap(swapData)

        let parsedDeeplink = try parser.parse(string: string)

        XCTAssertEqual(parsedDeeplink, result)
    }

    func testSwapTonkeeperUniversalLinkParsing() throws {
        let string = "https://app.tonkeeper.com/swap?ft=TON&tt=FNZ"
        let swapData = Deeplink.SwapData(
            fromToken: "TON",
            toToken: "FNZ"
        )
        let result = Deeplink.swap(swapData)

        let parsedDeeplink = try parser.parse(string: string)

        XCTAssertEqual(parsedDeeplink, result)
    }

    func testActionTonDeeplinkParsing() throws {
        let string = "ton://action/f0389f350dd7b6bba35ce0dd12d4e2cf557c2613bca2426d2e0c3055ac105994"
        let result = Deeplink.action(eventId: "f0389f350dd7b6bba35ce0dd12d4e2cf557c2613bca2426d2e0c3055ac105994")

        let parsedDeeplink = try parser.parse(string: string)

        XCTAssertEqual(parsedDeeplink, result)
    }

    func testActionTonkeeperDeeplinkParsing() throws {
        let string = "tonkeeper://action/f0389f350dd7b6bba35ce0dd12d4e2cf557c2613bca2426d2e0c3055ac105994"
        let result = Deeplink.action(eventId: "f0389f350dd7b6bba35ce0dd12d4e2cf557c2613bca2426d2e0c3055ac105994")

        let parsedDeeplink = try parser.parse(string: string)

        XCTAssertEqual(parsedDeeplink, result)
    }

    func testActionTonkeeperUniversalLinkParsing() throws {
        let string = "https://app.tonkeeper.com/action/f0389f350dd7b6bba35ce0dd12d4e2cf557c2613bca2426d2e0c3055ac105994"
        let result = Deeplink.action(eventId: "f0389f350dd7b6bba35ce0dd12d4e2cf557c2613bca2426d2e0c3055ac105994")

        let parsedDeeplink = try parser.parse(string: string)

        XCTAssertEqual(parsedDeeplink, result)
    }

    func testPoolTonDeeplinkParsing() throws {
        let string = "ton://pool/0:a45b17f28409229b78360e3290420f13e4fe20f90d7e2bf8c4ac6703259e22fa"
        let result = try Deeplink.pool(Address.parse("0:a45b17f28409229b78360e3290420f13e4fe20f90d7e2bf8c4ac6703259e22fa"))

        let parsedDeeplink = try parser.parse(string: string)

        XCTAssertEqual(parsedDeeplink, result)
    }

    func testPoolTonkeeperDeeplinkParsing() throws {
        let string = "tonkeeper://pool/0:a45b17f28409229b78360e3290420f13e4fe20f90d7e2bf8c4ac6703259e22fa"
        let result = try Deeplink.pool(Address.parse("0:a45b17f28409229b78360e3290420f13e4fe20f90d7e2bf8c4ac6703259e22fa"))

        let parsedDeeplink = try parser.parse(string: string)

        XCTAssertEqual(parsedDeeplink, result)
    }

    func testPoolTonkeeperUnversalLinkParsing() throws {
        let string = "https://app.tonkeeper.com/pool/0:a45b17f28409229b78360e3290420f13e4fe20f90d7e2bf8c4ac6703259e22fa"
        let result = try Deeplink.pool(Address.parse("0:a45b17f28409229b78360e3290420f13e4fe20f90d7e2bf8c4ac6703259e22fa"))

        let parsedDeeplink = try parser.parse(string: string)

        XCTAssertEqual(parsedDeeplink, result)
    }

    func testPublishTonDeeplinkParsing() throws {
        let string = "ton://publish?sign=9dfab96f693363f48a641c628ae74168d37f7da1745bfd3cbf1b6013cce1477c03ae59e87c8ebe0146c1d755b797020ac29ff6a1797e7ae7d4b61df89c34540f"
        let data: Data = Data(hex: "9dfab96f693363f48a641c628ae74168d37f7da1745bfd3cbf1b6013cce1477c03ae59e87c8ebe0146c1d755b797020ac29ff6a1797e7ae7d4b61df89c34540f")
        let result = Deeplink.publish(sign: data)

        let parsedDeeplink = try parser.parse(string: string)

        XCTAssertEqual(parsedDeeplink, result)
    }

    func testPublishTonkeeperDeeplinkParsing() throws {
        let string = "tonkeeper://publish?sign=9dfab96f693363f48a641c628ae74168d37f7da1745bfd3cbf1b6013cce1477c03ae59e87c8ebe0146c1d755b797020ac29ff6a1797e7ae7d4b61df89c34540f"
        let data: Data = Data(hex: "9dfab96f693363f48a641c628ae74168d37f7da1745bfd3cbf1b6013cce1477c03ae59e87c8ebe0146c1d755b797020ac29ff6a1797e7ae7d4b61df89c34540f")
        let result = Deeplink.publish(sign: data)

        let parsedDeeplink = try parser.parse(string: string)

        XCTAssertEqual(parsedDeeplink, result)
    }

    func testPublishTonkeeperUniversalLinkParsing() throws {
        let string = "https://app.tonkeeper.com/publish?sign=9dfab96f693363f48a641c628ae74168d37f7da1745bfd3cbf1b6013cce1477c03ae59e87c8ebe0146c1d755b797020ac29ff6a1797e7ae7d4b61df89c34540f"
        let data: Data = Data(hex: "9dfab96f693363f48a641c628ae74168d37f7da1745bfd3cbf1b6013cce1477c03ae59e87c8ebe0146c1d755b797020ac29ff6a1797e7ae7d4b61df89c34540f")
        let result = Deeplink.publish(sign: data)

        let parsedDeeplink = try parser.parse(string: string)

        XCTAssertEqual(parsedDeeplink, result)
    }

    func testSignerLinkTonDeeplinkParsing() throws {
        let pk = "db642e022c80911fe61f19eb4f22d7fb95c1ea0b589c0f74ecf0cbf6db746c13"
        let name = "MyKey"
        let publicKey = TonSwift.PublicKey(data: Data(hex: pk))
        let string = "ton://signer/link?pk=\(pk)&name=\(name)"
        let result = Deeplink.externalSign(
            ExternalSignDeeplink.link(
                publicKey: publicKey,
                name: name
            )
        )

        let parsedDeeplink = try parser.parse(string: string)

        XCTAssertEqual(parsedDeeplink, result)
    }

    func testSignerLinkTonkeeperDeeplinkParsing() throws {
        let pk = "db642e022c80911fe61f19eb4f22d7fb95c1ea0b589c0f74ecf0cbf6db746c13"
        let name = "MyKey"
        let publicKey = TonSwift.PublicKey(data: Data(hex: pk))
        let string = "tonkeeper://signer/link?pk=\(pk)&name=\(name)"
        let result = Deeplink.externalSign(
            ExternalSignDeeplink.link(
                publicKey: publicKey,
                name: name
            )
        )

        let parsedDeeplink = try parser.parse(string: string)

        XCTAssertEqual(parsedDeeplink, result)
    }

    func testSignerLinkTonkeeperUniversalLinkParsing() throws {
        let pk = "db642e022c80911fe61f19eb4f22d7fb95c1ea0b589c0f74ecf0cbf6db746c13"
        let name = "MyKey"
        let publicKey = TonSwift.PublicKey(data: Data(hex: pk))
        let string = "https://app.tonkeeper.com/signer/link?pk=\(pk)&name=\(name)"
        let result = Deeplink.externalSign(
            ExternalSignDeeplink.link(
                publicKey: publicKey,
                name: name
            )
        )

        let parsedDeeplink = try parser.parse(string: string)

        XCTAssertEqual(parsedDeeplink, result)
    }

    func testReceiveTonkeeperDeeplinkParsing() throws {
        let string = "tonkeeper://receive"
        let result = Deeplink.receive

        let parsedDeeplink = try parser.parse(string: string)

        XCTAssertEqual(parsedDeeplink, result)
    }

    func testReceiveTonDeeplinkParsing() throws {
        let string = "ton://receive"
        let result = Deeplink.receive

        let parsedDeeplink = try parser.parse(string: string)

        XCTAssertEqual(parsedDeeplink, result)
    }

    func testBackupTonkeeperDeeplinkParsing() throws {
        let string = "tonkeeper://backup"
        let result = Deeplink.backup

        let parsedDeeplink = try parser.parse(string: string)

        XCTAssertEqual(parsedDeeplink, result)
    }

    func testBackupTonDeeplinkParsing() throws {
        let string = "ton://backup"
        let result = Deeplink.backup

        let parsedDeeplink = try parser.parse(string: string)

        XCTAssertEqual(parsedDeeplink, result)
    }
}
