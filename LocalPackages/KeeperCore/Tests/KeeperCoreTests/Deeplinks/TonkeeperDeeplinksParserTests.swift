import BigInt
@testable import KeeperCore
import KeeperCoreComponents
import TonSwift
import XCTest

final class TonkeeperDeeplinksParserTests: XCTestCase {
    let parser = TonkeeperDeeplinkParser(
        walletConnectDeeplinkValidator: WalletConnectDeeplinkValidatorImplementation()
    )

    func testTransferParsing() throws {
        let address = "EQD2NmD_lH5f5u1Kj3KfGyTvhZSX0Eg6qp2a5IQUKXxOG21n"
        let text = "just comment"
        let amount = "10000"

        let string = "transfer/\(address)?text=\(text)&amount=\(amount)"
        let transferData = Deeplink.TransferData(
            recipient: address,
            amount: BigUInt(amount),
            comment: text,
            jettonAddress: nil,
            assetId: nil,
            expirationTimestamp: nil,
            successReturn: nil
        )
        let result = Deeplink.transfer(.sendTransfer(transferData))

        let parsedDeeplink = try parser.parse(string: string)

        XCTAssertEqual(parsedDeeplink, result)
    }

    func testTransferAssetIdParsing() throws {
        let address = "EQD2NmD_lH5f5u1Kj3KfGyTvhZSX0Eg6qp2a5IQUKXxOG21n"
        let assetId = "ton/mainnet/coin"

        let parsedDeeplink = try parser.parse(string: "transfer/\(address)?asset_id=\(assetId)&amount=10000")

        XCTAssertEqual(
            parsedDeeplink,
            Deeplink.transfer(
                .sendTransfer(
                    Deeplink.TransferData(
                        recipient: address,
                        amount: BigUInt(10000),
                        comment: nil,
                        jettonAddress: nil,
                        assetId: assetId,
                        expirationTimestamp: nil,
                        successReturn: nil
                    )
                )
            )
        )
    }

    func testTransferKeepsBothAssetIdAndJetton() throws {
        let address = "EQD2NmD_lH5f5u1Kj3KfGyTvhZSX0Eg6qp2a5IQUKXxOG21n"
        let jetton = "EQCxE6mUtQJKFnGfaROTKOt1lZbDiiX1kCixRv7Nw2Id_sDs"
        let assetId = "ton/mainnet/jetton/\(jetton)"

        let parsedDeeplink = try parser.parse(
            string: "transfer/\(address)?jetton=\(jetton)&asset_id=\(assetId)"
        )

        XCTAssertEqual(
            parsedDeeplink,
            try Deeplink.transfer(
                .sendTransfer(
                    Deeplink.TransferData(
                        recipient: address,
                        amount: nil,
                        comment: nil,
                        jettonAddress: Address.parse(jetton),
                        assetId: assetId,
                        expirationTimestamp: nil,
                        successReturn: nil
                    )
                )
            )
        )
    }

    func testTransferBlankAssetIdIsDropped() throws {
        let address = "EQD2NmD_lH5f5u1Kj3KfGyTvhZSX0Eg6qp2a5IQUKXxOG21n"

        let parsedDeeplink = try parser.parse(string: "transfer/\(address)?asset_id=%20")

        XCTAssertEqual(
            parsedDeeplink,
            Deeplink.transfer(
                .sendTransfer(
                    Deeplink.TransferData(
                        recipient: address,
                        amount: nil,
                        comment: nil,
                        jettonAddress: nil,
                        assetId: nil,
                        expirationTimestamp: nil,
                        successReturn: nil
                    )
                )
            )
        )
    }

    /// A payload turns the link into a raw transfer, where the asset comes from the payload itself.
    func testTransferAssetIdWithBinStaysSignRaw() throws {
        let address = "EQD2NmD_lH5f5u1Kj3KfGyTvhZSX0Eg6qp2a5IQUKXxOG21n"

        let parsedDeeplink = try parser.parse(
            string: "transfer/\(address)?asset_id=ton/mainnet/coin&bin=te6ccgEBAQEAAgAAAA==&amount=1"
        )

        XCTAssertEqual(
            parsedDeeplink,
            Deeplink.transfer(
                .signRawTransfer(
                    Deeplink.RawTransferData(
                        recipient: address,
                        amount: BigUInt(1),
                        jettonAddress: nil,
                        bin: "te6ccgEBAQEAAgAAAA==",
                        stateInit: nil,
                        expirationTimestamp: nil
                    )
                )
            )
        )
    }

    func testTransferUnknownQueryItemStillThrows() {
        let address = "EQD2NmD_lH5f5u1Kj3KfGyTvhZSX0Eg6qp2a5IQUKXxOG21n"

        XCTAssertThrowsError(try parser.parse(string: "transfer/\(address)?asset=ton/mainnet/coin")) { error in
            XCTAssertEqual(error as? DeeplinkParserError, .unknownQueryItem(name: "asset"))
        }
    }

    func testTransferKeepsUtmQueryItems() throws {
        let address = "EQD2NmD_lH5f5u1Kj3KfGyTvhZSX0Eg6qp2a5IQUKXxOG21n"
        let utm = UtmParameters.queryItemNames.map { "\($0)=promo" }.joined(separator: "&")

        let parsedDeeplink = try parser.parse(string: "transfer/\(address)?amount=10000&\(utm)")

        XCTAssertEqual(
            parsedDeeplink,
            Deeplink.transfer(
                .sendTransfer(
                    Deeplink.TransferData(
                        recipient: address,
                        amount: BigUInt(10000),
                        comment: nil,
                        jettonAddress: nil,
                        assetId: nil,
                        expirationTimestamp: nil,
                        successReturn: nil
                    )
                )
            )
        )
    }

    func testStakingParsing() throws {
        let string = "staking"
        let result = Deeplink.staking

        let parsedDeeplink = try parser.parse(string: string)

        XCTAssertEqual(parsedDeeplink, result)
    }

    func testSwapParsing() throws {
        let string = "swap?ft=TON&tt=FNZ"
        let swapData = Deeplink.SwapData(
            fromToken: "TON",
            toToken: "FNZ"
        )
        let result = Deeplink.swap(swapData)

        let parsedDeeplink = try parser.parse(string: string)

        XCTAssertEqual(parsedDeeplink, result)
    }

    func testActionParsing() throws {
        let string = "action/f0389f350dd7b6bba35ce0dd12d4e2cf557c2613bca2426d2e0c3055ac105994"
        let result = Deeplink.action(eventId: "f0389f350dd7b6bba35ce0dd12d4e2cf557c2613bca2426d2e0c3055ac105994")

        let parsedDeeplink = try parser.parse(string: string)

        XCTAssertEqual(parsedDeeplink, result)
    }

    func testPoolParsing() throws {
        let string = "pool/0:a45b17f28409229b78360e3290420f13e4fe20f90d7e2bf8c4ac6703259e22fa"
        let result = try Deeplink.pool(Address.parse("0:a45b17f28409229b78360e3290420f13e4fe20f90d7e2bf8c4ac6703259e22fa"))

        let parsedDeeplink = try parser.parse(string: string)

        XCTAssertEqual(parsedDeeplink, result)
    }

    func testPublishParsing() throws {
        let string = "publish?sign=9dfab96f693363f48a641c628ae74168d37f7da1745bfd3cbf1b6013cce1477c03ae59e87c8ebe0146c1d755b797020ac29ff6a1797e7ae7d4b61df89c34540f"
        let data = try XCTUnwrap(Data(strictHex: "9dfab96f693363f48a641c628ae74168d37f7da1745bfd3cbf1b6013cce1477c03ae59e87c8ebe0146c1d755b797020ac29ff6a1797e7ae7d4b61df89c34540f"))
        let result = Deeplink.publish(sign: data)

        let parsedDeeplink = try parser.parse(string: string)

        XCTAssertEqual(parsedDeeplink, result)
    }

    func testSignerLinkParsing() throws {
        let pk = "db642e022c80911fe61f19eb4f22d7fb95c1ea0b589c0f74ecf0cbf6db746c13"
        let name = "MyKey"
        let publicKey = try TonSwift.PublicKey(data: XCTUnwrap(Data(strictHex: pk)))
        let string = "signer/link?pk=\(pk)&name=\(name)"
        let result = Deeplink.externalSign(
            ExternalSignDeeplink.link(
                publicKey: publicKey,
                name: name
            )
        )

        let parsedDeeplink = try parser.parse(string: string)

        XCTAssertEqual(parsedDeeplink, result)
    }

    func testReceiveParsing() throws {
        let string = "receive"
        let result = Deeplink.receive

        let parsedDeeplink = try parser.parse(string: string)

        XCTAssertEqual(parsedDeeplink, result)
    }

    func testBackupParsing() throws {
        let string = "backup"
        let result = Deeplink.backup

        let parsedDeeplink = try parser.parse(string: string)

        XCTAssertEqual(parsedDeeplink, result)
    }

    func testAddWalletParsing() throws {
        XCTAssertEqual(try parser.parse(string: "add-wallet"), .addWallet)
    }

    func testMainParsing() throws {
        let string = "main"
        let result = Deeplink.main

        let parsedDeeplink = try parser.parse(string: string)

        XCTAssertEqual(parsedDeeplink, result)
    }

    func testEmptyPathMainParsing() throws {
        let string = ""
        let result = Deeplink.main

        let parsedDeeplink = try parser.parse(string: string)

        XCTAssertEqual(parsedDeeplink, result)
    }

    func testDepositParsing() throws {
        let params = RampDeeplinkParameters(
            fromToken: "USDT",
            toToken: "USDT",
            toNetwork: "trc20",
            fromNetwork: "ton",
            cashMethod: "card"
        )
        let string = "deposit?ft=USDT&tt=USDT&tn=trc20&fn=ton&cm=card"
        let parsedDeeplink = try parser.parse(string: string)
        XCTAssertEqual(parsedDeeplink, Deeplink.deposit(params))
    }

    func testDepositParsingWithItemType() throws {
        let params = RampDeeplinkParameters(
            fromToken: "USDT",
            toToken: "USDT",
            toNetwork: "trc20",
            fromNetwork: "ton",
            cashMethod: "card",
            itemType: .stablecoin
        )
        let string = "deposit?ft=USDT&tt=USDT&tn=trc20&fn=ton&cm=card&it=stablecoin"
        let parsedDeeplink = try parser.parse(string: string)
        XCTAssertEqual(parsedDeeplink, Deeplink.deposit(params))
    }

    func testWithdrawParsingItemTypeCaseInsensitive() throws {
        let params = RampDeeplinkParameters(
            fromToken: "TON",
            toToken: nil,
            toNetwork: nil,
            fromNetwork: nil,
            cashMethod: nil,
            itemType: .fiat
        )
        let parsedDeeplink = try parser.parse(string: "withdraw?ft=TON&it=FIAT")
        XCTAssertEqual(parsedDeeplink, Deeplink.withdraw(params))
    }

    func testWithdrawParsing() throws {
        let params = RampDeeplinkParameters(
            fromToken: "TON",
            toToken: nil,
            toNetwork: nil,
            fromNetwork: nil,
            cashMethod: nil
        )
        let parsedDeeplink = try parser.parse(string: "withdraw?ft=TON")
        XCTAssertEqual(parsedDeeplink, Deeplink.withdraw(params))
    }

    func testRaffleParsing() throws {
        XCTAssertEqual(try parser.parse(string: "raffle"), Deeplink.raffle)
    }

    func testMysteryRaffleParsing() throws {
        XCTAssertEqual(try parser.parse(string: "raffle/mystery_raffle"), Deeplink.raffle)
    }

    func testUnsupportedRafflePathThrows() {
        XCTAssertThrowsError(try parser.parse(string: "raffle/unknown"))
    }
}
