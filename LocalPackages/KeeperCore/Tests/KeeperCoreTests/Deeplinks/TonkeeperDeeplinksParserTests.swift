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
        XCTAssertEqual(try parser.parse(string: "raffle"), Deeplink.raffle(id: nil))
    }

    func testMysteryRaffleParsing() throws {
        XCTAssertEqual(try parser.parse(string: "raffle/mystery_raffle"), Deeplink.raffle(id: "mystery_raffle"))
    }

    func testDinnerWithTrumpRaffleParsing() throws {
        XCTAssertEqual(
            try parser.parse(string: "raffle/dinner_with_trump"),
            try .dapp(XCTUnwrap(URL(string: "https://trump.keeperwallet.com/")))
        )
    }

    func testTrumpMultichainParsing() throws {
        XCTAssertEqual(
            try parser.parse(string: "trump-multichain"),
            try .multichainDapp(XCTUnwrap(URL(string: "https://trump.keeperwallet.com/")))
        )
    }

    func testUnknownRaffleIdParsing() throws {
        XCTAssertEqual(try parser.parse(string: "raffle/unknown"), Deeplink.raffle(id: "unknown"))
    }

    func testUnsupportedRafflePathThrows() {
        XCTAssertThrowsError(try parser.parse(string: "raffle/unknown/extra"))
    }

    func testPerpsParsing() throws {
        XCTAssertEqual(try parser.parse(string: "perps"), .perps(.home))
        XCTAssertEqual(try parser.parse(string: "perps/market/1"), .perps(.market(id: 1)))
        XCTAssertEqual(try parser.parse(string: "perps/market/1/position"), .perps(.market(id: 1)))
        XCTAssertEqual(try parser.parse(string: "perps/market/1/auto-close?utm_source=push"), .perps(.autoClose(marketId: 1)))
        XCTAssertEqual(try parser.parse(string: "perps/market/ANT"), .perps(.marketSymbol("ANT")))
        XCTAssertThrowsError(try parser.parse(string: "perps/market/ANT/auto-close"))
        XCTAssertThrowsError(try parser.parse(string: "perps/market/AN-T"))
        XCTAssertThrowsError(try parser.parse(string: "perps/positions"))
    }

    func testHistoryParsing() throws {
        XCTAssertEqual(try parser.parse(string: "history"), .history)
    }

    func testLoyaltyParsing() throws {
        XCTAssertEqual(try parser.parse(string: "loyalty?referral_code=Ab-9_x"), .loyalty(referralCode: "Ab-9_x"))
        XCTAssertEqual(try parser.parse(string: "loyalty?referral_code=%20Ab9%20"), .loyalty(referralCode: "Ab9"))
        XCTAssertEqual(try parser.parse(string: "loyalty"), .loyalty(referralCode: nil))
        XCTAssertEqual(try parser.parse(string: "loyalty?ref=Ab9"), .loyalty(referralCode: nil))
        XCTAssertEqual(try parser.parse(string: "loyalty%3Freferral_code%3DAb9"), .loyalty(referralCode: "Ab9"))
        XCTAssertEqual(try parser.parse(string: "loyalty?utm_content=x%26referral_code%3DAb9"), .loyalty(referralCode: nil))
        XCTAssertEqual(try parser.parse(string: "loyalty?referral_code%3DAb9"), .loyalty(referralCode: nil))
        if #available(iOS 17, *) {
            XCTAssertEqual(try parser.parse(string: "loyalty?referral_code=Ab9&utm_term=a b"), .loyalty(referralCode: "Ab9"))
        }
    }

    func testReferralPathParsing() throws {
        XCTAssertEqual(try parser.parse(string: "r/K7M2QX9P"), .loyalty(referralCode: "K7M2QX9P"))
        XCTAssertEqual(try parser.parse(string: "r/Ab-9_x?utm_source=x"), .loyalty(referralCode: "Ab-9_x"))
        XCTAssertEqual(try parser.parse(string: "r"), .loyalty(referralCode: nil))
        XCTAssertEqual(try parser.parse(string: "r/a.b"), .loyalty(referralCode: nil))
        XCTAssertEqual(try parser.parse(string: "r/%D0%BA%D0%BE%D0%B4"), .loyalty(referralCode: nil))
        XCTAssertEqual(try parser.parse(string: "r/\(String(repeating: "a", count: 65))"), .loyalty(referralCode: nil))
        XCTAssertEqual(try parser.parse(string: "r/Ab9/extra"), .loyalty(referralCode: nil))
    }

    func testLoyaltyDropsAnInvalidReferralCode() throws {
        let tooLong = String(repeating: "a", count: 65)
        XCTAssertEqual(try parser.parse(string: "loyalty?referral_code=\(tooLong)"), .loyalty(referralCode: nil))
        XCTAssertEqual(
            try parser.parse(string: "loyalty?referral_code=\(String(repeating: "a", count: 64))"),
            .loyalty(referralCode: String(repeating: "a", count: 64))
        )
        XCTAssertEqual(try parser.parse(string: "loyalty?referral_code="), .loyalty(referralCode: nil))
        XCTAssertEqual(try parser.parse(string: "loyalty?referral_code=a.b"), .loyalty(referralCode: nil))
        XCTAssertEqual(try parser.parse(string: "loyalty?referral_code=%D0%BA%D0%BE%D0%B4"), .loyalty(referralCode: nil))
        XCTAssertEqual(try parser.parse(string: "loyalty?referral_code=a%26b"), .loyalty(referralCode: nil))
        XCTAssertEqual(try parser.parse(string: "loyalty?referral_code=Ab9%23x"), .loyalty(referralCode: nil))
    }

    func testEarnParsing() throws {
        XCTAssertEqual(try parser.parse(string: "earn"), .earn(.home))
        XCTAssertEqual(try parser.parse(string: "earn?utm_source=push"), .earn(.home))
        XCTAssertEqual(try parser.parse(string: "earn?network=&vault="), .earn(.home))
    }

    func testEarnVaultParsing() throws {
        let vaultId = "0xc1256Ae5FF1cf2719D4937adb3bbCCab2E00A2Ca"

        XCTAssertEqual(
            try parser.parse(string: "earn?network=base&vault=\(vaultId)"),
            .earn(.vault(network: "base", vaultId: vaultId))
        )
        XCTAssertEqual(
            try parser.parse(string: "earn?vault=\(vaultId)-usdc&network=BSC&utm_source=push"),
            .earn(.vault(network: "bsc", vaultId: "\(vaultId)-usdc"))
        )
    }

    func testEarnVaultOutsideTheEarnRoutesThrows() {
        let vaultId = "0xc1256Ae5FF1cf2719D4937adb3bbCCab2E00A2Ca"
        let links = [
            "earn?network=optimism&vault=\(vaultId)",
            "earn?network=eth&vault=\(vaultId)",
            "earn?network=base&vault=0xc1256Ae5",
            "earn?network=base&vault=\(vaultId)-",
            "earn?network=base&vault=\(vaultId)-a%2F..%2F..%2Fswap",
            "earn?network=base",
            "earn?network=base&vault=",
            "earn?vault=\(vaultId)",
        ]

        for link in links {
            XCTAssertThrowsError(try parser.parse(string: link), link) { error in
                XCTAssertEqual(error as? DeeplinkParserError, .invalidParameters, link)
            }
        }
    }
}
