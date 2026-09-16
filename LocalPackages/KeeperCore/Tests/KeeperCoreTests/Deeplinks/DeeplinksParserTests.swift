import BigInt
@testable import KeeperCore
import KeeperCoreComponents
import TonSwift
import XCTest

final class DeeplinksParserTests: XCTestCase {
    let parser = DeeplinkParser(
        walletConnectDeeplinkValidator: WalletConnectDeeplinkValidatorImplementation()
    )

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
            assetId: nil,
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
            assetId: nil,
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
            assetId: nil,
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
        let data = try XCTUnwrap(Data(strictHex: "9dfab96f693363f48a641c628ae74168d37f7da1745bfd3cbf1b6013cce1477c03ae59e87c8ebe0146c1d755b797020ac29ff6a1797e7ae7d4b61df89c34540f"))
        let result = Deeplink.publish(sign: data)

        let parsedDeeplink = try parser.parse(string: string)

        XCTAssertEqual(parsedDeeplink, result)
    }

    func testPublishTonkeeperDeeplinkParsing() throws {
        let string = "tonkeeper://publish?sign=9dfab96f693363f48a641c628ae74168d37f7da1745bfd3cbf1b6013cce1477c03ae59e87c8ebe0146c1d755b797020ac29ff6a1797e7ae7d4b61df89c34540f"
        let data = try XCTUnwrap(Data(strictHex: "9dfab96f693363f48a641c628ae74168d37f7da1745bfd3cbf1b6013cce1477c03ae59e87c8ebe0146c1d755b797020ac29ff6a1797e7ae7d4b61df89c34540f"))
        let result = Deeplink.publish(sign: data)

        let parsedDeeplink = try parser.parse(string: string)

        XCTAssertEqual(parsedDeeplink, result)
    }

    func testPublishTonkeeperUniversalLinkParsing() throws {
        let string = "https://app.tonkeeper.com/publish?sign=9dfab96f693363f48a641c628ae74168d37f7da1745bfd3cbf1b6013cce1477c03ae59e87c8ebe0146c1d755b797020ac29ff6a1797e7ae7d4b61df89c34540f"
        let data = try XCTUnwrap(Data(strictHex: "9dfab96f693363f48a641c628ae74168d37f7da1745bfd3cbf1b6013cce1477c03ae59e87c8ebe0146c1d755b797020ac29ff6a1797e7ae7d4b61df89c34540f"))
        let result = Deeplink.publish(sign: data)

        let parsedDeeplink = try parser.parse(string: string)

        XCTAssertEqual(parsedDeeplink, result)
    }

    func testSignerLinkTonDeeplinkParsing() throws {
        let pk = "db642e022c80911fe61f19eb4f22d7fb95c1ea0b589c0f74ecf0cbf6db746c13"
        let name = "MyKey"
        let publicKey = try TonSwift.PublicKey(data: XCTUnwrap(Data(strictHex: pk)))
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
        let publicKey = try TonSwift.PublicKey(data: XCTUnwrap(Data(strictHex: pk)))
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
        let publicKey = try TonSwift.PublicKey(data: XCTUnwrap(Data(strictHex: pk)))
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

    func testAddWalletTonkeeperDeeplinkParsing() throws {
        XCTAssertEqual(try parser.parse(string: "tonkeeper://add-wallet"), .addWallet)
    }

    func testDepositUniversalLinkParsing() throws {
        let params = RampDeeplinkParameters(
            fromToken: "TON",
            toToken: nil,
            toNetwork: nil,
            fromNetwork: nil,
            cashMethod: nil
        )
        let string = "https://app.tonkeeper.com/deposit?ft=TON"
        let parsedDeeplink = try parser.parse(string: string)
        XCTAssertEqual(parsedDeeplink, Deeplink.deposit(params))
    }

    func testWithdrawUniversalLinkParsing() throws {
        let params = RampDeeplinkParameters(
            fromToken: "USDT",
            toToken: "USDT",
            toNetwork: "ton",
            fromNetwork: "trc20",
            cashMethod: nil
        )
        let string = "https://app.tonkeeper.com/withdraw?ft=USDT&fn=trc20&tt=USDT&tn=ton"
        let parsedDeeplink = try parser.parse(string: string)
        XCTAssertEqual(parsedDeeplink, Deeplink.withdraw(params))
    }

    func testTradingUniversalLinkParsing() throws {
        let string = "https://app.tonkeeper.com/trading"
        let parsedDeeplink = try parser.parse(string: string)
        XCTAssertEqual(parsedDeeplink, Deeplink.trading(gridID: nil))
    }

    func testTradingGridUniversalLinkParsing() throws {
        let string = "https://app.tonkeeper.com/trading/most_traded"
        let parsedDeeplink = try parser.parse(string: string)
        XCTAssertEqual(parsedDeeplink, Deeplink.trading(gridID: "most_traded"))
    }

    func testTradeAssetUniversalLinkParsing() throws {
        let assetID = "ton/mainnet/jetton/0:abcdef"
        let string = "https://app.tonkeeper.com/assets/\(assetID)"
        let parsedDeeplink = try parser.parse(string: string)
        XCTAssertEqual(parsedDeeplink, Deeplink.tradeAsset(assetID: assetID))
    }

    func testBrowserUniversalLinkParsing() throws {
        let string = "https://app.tonkeeper.com/browser"
        let parsedDeeplink = try parser.parse(string: string)
        XCTAssertEqual(parsedDeeplink, Deeplink.browser(network: nil))
    }

    func testBrowserNetworkUniversalLinkParsing() throws {
        let string = "https://app.tonkeeper.com/browser?network=tron"
        let parsedDeeplink = try parser.parse(string: string)
        XCTAssertEqual(parsedDeeplink, Deeplink.browser(network: .tron))
    }

    func testBrowserNetworkTrxAliasParsing() throws {
        let string = "https://app.tonkeeper.com/browser?network=trx"
        let parsedDeeplink = try parser.parse(string: string)
        XCTAssertEqual(parsedDeeplink, Deeplink.browser(network: .tron))
    }

    func testBrowserUnknownNetworkParsing() throws {
        let string = "https://app.tonkeeper.com/browser?network=foo"
        let parsedDeeplink = try parser.parse(string: string)
        XCTAssertEqual(parsedDeeplink, Deeplink.browser(network: nil))
    }

    func testMigrationUniversalLinkParsing() throws {
        let string = "https://app.tonkeeper.com/migration"
        let parsedDeeplink = try parser.parse(string: string)
        XCTAssertEqual(parsedDeeplink, Deeplink.migration)
    }

    func testMigrateAliasParsing() throws {
        XCTAssertEqual(try parser.parse(string: "tonkeeper://migrate"), Deeplink.migration)
        XCTAssertEqual(try parser.parse(string: "https://app.tonkeeper.com/migrate"), Deeplink.migration)
    }

    func testMainUniversalLinkParsing() throws {
        let string = "https://app.tonkeeper.com/main"
        let parsedDeeplink = try parser.parse(string: string)
        XCTAssertEqual(parsedDeeplink, Deeplink.main)
    }

    func testMainUniversalLinkAppHostRootPath() throws {
        let string = "https://app.tonkeeper.com/"
        let parsedDeeplink = try parser.parse(string: string)
        XCTAssertEqual(parsedDeeplink, Deeplink.main)
    }

    func testWalletConnectRawURIParsing() throws {
        let uri = "wc:123@2?relay-protocol=irn&symKey=abc"
        let parsedDeeplink = try parser.parse(string: uri)
        XCTAssertEqual(
            parsedDeeplink,
            Deeplink.walletConnect(WalletConnectDeeplink(uri: uri, source: .deeplink))
        )
    }

    func testWalletConnectRawURIParsingUsesProvidedQRSource() throws {
        let uri = "wc:123@2?relay-protocol=irn&symKey=abc"
        let parsedDeeplink = try parser.parse(string: uri, source: .qr)
        XCTAssertEqual(
            parsedDeeplink,
            Deeplink.walletConnect(WalletConnectDeeplink(uri: uri, source: .qr))
        )
    }

    func testWalletConnectRawURIWithExpiryTimestampParsing() throws {
        let uri = "wc:d14c5131edc3120a50f9480701665bc2a4d9ca0d66684bb455ad184ce60cad3d@2?expiryTimestamp=1779080068&relay-protocol=irn&symKey=f4ddb9526260f561d3c87e66bf49cca0b50c02ca2120108fbfa15b31341a47d5"
        let parsedDeeplink = try parser.parse(string: uri)
        XCTAssertEqual(
            parsedDeeplink,
            Deeplink.walletConnect(WalletConnectDeeplink(uri: uri, source: .deeplink))
        )
    }

    func testWalletConnectRawURIParsingTrimsAndNormalizesScheme() throws {
        let uri = "wc:123@2?relay-protocol=irn&symKey=abc"
        let parsedDeeplink = try parser.parse(string: " \nWC:123@2?relay-protocol=irn&symKey=abc\t")
        XCTAssertEqual(
            parsedDeeplink,
            Deeplink.walletConnect(WalletConnectDeeplink(uri: uri, source: .deeplink))
        )
    }

    func testWalletConnectTonkeeperDeeplinkParsing() throws {
        let uri = "wc:123@2?relay-protocol=irn&symKey=abc"
        let string = "tonkeeper://wc?uri=wc%3A123%402%3Frelay-protocol%3Dirn%26symKey%3Dabc"
        let parsedDeeplink = try parser.parse(string: string)
        XCTAssertEqual(
            parsedDeeplink,
            Deeplink.walletConnect(WalletConnectDeeplink(uri: uri, source: .deeplink))
        )
    }

    func testWalletConnectTonkeeperDocsFormatDeeplinkParsing() throws {
        let uri = "wc:123@2?relay-protocol=irn&symKey=abc"
        let string = "tonkeeper://wc?uri=wc:123@2?relay-protocol=irn&symKey=abc"
        let parsedDeeplink = try parser.parse(string: string)
        XCTAssertEqual(
            parsedDeeplink,
            Deeplink.walletConnect(WalletConnectDeeplink(uri: uri, source: .deeplink))
        )
    }

    func testWalletConnectUniversalLinkParsing() throws {
        let uri = "wc:123@2?relay-protocol=irn&symKey=abc"
        let string = "https://app.tonkeeper.com/wc?uri=wc%3A123%402%3Frelay-protocol%3Dirn%26symKey%3Dabc"
        let parsedDeeplink = try parser.parse(string: string)
        XCTAssertEqual(
            parsedDeeplink,
            Deeplink.walletConnect(WalletConnectDeeplink(uri: uri, source: .deeplink))
        )
    }

    func testWalletConnectUniversalDocsFormatLinkParsing() throws {
        let uri = "wc:123@2?relay-protocol=irn&symKey=abc"
        let string = "https://app.tonkeeper.com/wc?uri=wc:123@2?relay-protocol=irn&symKey=abc"
        let parsedDeeplink = try parser.parse(string: string)
        XCTAssertEqual(
            parsedDeeplink,
            Deeplink.walletConnect(WalletConnectDeeplink(uri: uri, source: .deeplink))
        )
    }

    func testWalletConnectRawIncompleteURIIsIgnored() throws {
        XCTAssertThrowsError(try parser.parse(string: "wc:123@2")) { error in
            XCTAssertEqual(error as? DeeplinkParserError, .ignoredWalletConnectWakeUp)
        }
    }

    func testWalletConnectTonkeeperIncompleteURIIsIgnored() throws {
        XCTAssertThrowsError(try parser.parse(string: "tonkeeper://wc?uri=wc%3A123%402")) { error in
            XCTAssertEqual(error as? DeeplinkParserError, .ignoredWalletConnectWakeUp)
        }
    }

    func testWalletConnectUniversalIncompleteURIIsIgnored() throws {
        XCTAssertThrowsError(try parser.parse(string: "https://app.tonkeeper.com/wc?uri=wc%3A123%402")) { error in
            XCTAssertEqual(error as? DeeplinkParserError, .ignoredWalletConnectWakeUp)
        }
    }

    func testWalletConnectWrappedIncompleteURIWithOuterQueryIsIgnored() throws {
        XCTAssertThrowsError(try parser.parse(string: "tonkeeper://wc?uri=wc%3A123%402&source=outer")) { error in
            XCTAssertEqual(error as? DeeplinkParserError, .ignoredWalletConnectWakeUp)
        }
    }

    func testWalletConnectUniversalSessionRequestRedirectIsIgnored() {
        let string = "https://app.tonkeeper.com/wc?requestId=1787580460495163&sessionTopic=ac8d427e8f4c76c5cb1b8920d82a0944d910f5c3b96"
        XCTAssertThrowsError(try parser.parse(string: string)) { error in
            XCTAssertEqual(error as? DeeplinkParserError, .ignoredWalletConnectWakeUp)
        }
    }

    func testWalletConnectCustomSchemeSessionRequestRedirectIsIgnored() {
        let string = "tonkeeper://wc?requestId=1787580460495163&sessionTopic=ac8d427e8f4c76c5cb1b8920d82a0944d910f5c3b96"
        XCTAssertThrowsError(try parser.parse(string: string)) { error in
            XCTAssertEqual(error as? DeeplinkParserError, .ignoredWalletConnectWakeUp)
        }
    }

    func testWalletConnectTonSchemeSessionRequestRedirectIsIgnored() {
        XCTAssertThrowsError(try parser.parse(string: "ton://wc?sessionTopic=topic")) { error in
            XCTAssertEqual(error as? DeeplinkParserError, .ignoredWalletConnectWakeUp)
        }
    }

    func testWalletConnectMobSchemeSessionRequestRedirectIsIgnored() {
        XCTAssertThrowsError(try parser.parse(string: "tonkeeper-mob://wc?requestId=1787580460495163")) { error in
            XCTAssertEqual(error as? DeeplinkParserError, .ignoredWalletConnectWakeUp)
        }
    }

    func testWalletConnectSessionRequestRedirectWithTrailingSlashIsIgnored() {
        let string = "https://app.tonkeeper.com/wc/?requestId=1787580460495163&sessionTopic=topic"
        XCTAssertThrowsError(try parser.parse(string: string)) { error in
            XCTAssertEqual(error as? DeeplinkParserError, .ignoredWalletConnectWakeUp)
        }
    }

    func testWalletConnectContainerWithInvalidWrappedURIIsReported() {
        let string = "https://app.tonkeeper.com/wc?uri=notAWalletConnectURI"
        XCTAssertThrowsError(try parser.parse(string: string)) { error in
            XCTAssertEqual(
                error as? DeeplinkParserError,
                .unsupportedDeeplink(code: .notSupportedPath, string: string)
            )
        }
    }

    func testWalletConnectBareCustomSchemeRedirectIsIgnored() {
        XCTAssertThrowsError(try parser.parse(string: "tonkeeper://wc")) { error in
            XCTAssertEqual(error as? DeeplinkParserError, .ignoredWalletConnectWakeUp)
        }
    }

    func testWalletConnectBareUniversalRedirectIsIgnored() {
        XCTAssertThrowsError(try parser.parse(string: "https://app.tonkeeper.com/wc")) { error in
            XCTAssertEqual(error as? DeeplinkParserError, .ignoredWalletConnectWakeUp)
        }
    }

    func testWalletConnectRedirectWithUnknownQueryIsIgnored() {
        XCTAssertThrowsError(try parser.parse(string: "https://app.tonkeeper.com/wc?sessionTopic=")) { error in
            XCTAssertEqual(error as? DeeplinkParserError, .ignoredWalletConnectWakeUp)
        }
    }

    func testWalletConnectLinkModeEnvelopeIsIgnored() {
        let string = "https://app.tonkeeper.com/wc?wc_ev=eyJ0IjoiMSJ9&topic=abc"
        XCTAssertThrowsError(try parser.parse(string: string)) { error in
            XCTAssertEqual(error as? DeeplinkParserError, .ignoredWalletConnectWakeUp)
        }
    }

    func testWalletConnectDeepPathRedirectIsIgnored() {
        XCTAssertThrowsError(try parser.parse(string: "https://app.tonkeeper.com/wc/session/request")) { error in
            XCTAssertEqual(error as? DeeplinkParserError, .ignoredWalletConnectWakeUp)
        }
    }

    func testEthereumErc20TransferLinkParsing() throws {
        let contract = "0xdac17f958d2ee523a2206206994597c13d831ec7"
        let recipient = "0x8e23ee67d1332ad560396262c48ffbb01f93d052"

        let parsedDeeplink = try parser.parse(
            string: "ethereum:\(contract)@1/transfer?address=\(recipient)&uint256=1e6"
        )

        XCTAssertEqual(
            parsedDeeplink,
            .transfer(
                .evmSendTransfer(
                    Deeplink.EvmTransferData(
                        recipient: recipient,
                        asset: .erc20(contract: contract),
                        chain: .eth,
                        amount: BigUInt(1_000_000)
                    )
                )
            )
        )
    }

    func testEthereumNativeTransferLinkParsing() throws {
        let recipient = "0x8e23ee67d1332ad560396262c48ffbb01f93d052"

        let parsedDeeplink = try parser.parse(string: "ethereum:\(recipient)?value=2.014e18")

        XCTAssertEqual(
            parsedDeeplink,
            .transfer(
                .evmSendTransfer(
                    Deeplink.EvmTransferData(
                        recipient: recipient,
                        asset: .native,
                        chain: nil,
                        amount: BigUInt("2014000000000000000")
                    )
                )
            )
        )
    }

    func testUnsupportedEthereumLinkStaysUnsupported() throws {
        XCTAssertThrowsError(
            try parser.parse(string: "ethereum:0xdac17f958d2ee523a2206206994597c13d831ec7@137")
        ) { error in
            XCTAssertEqual(
                error as? DeeplinkParserError,
                .unsupportedDeeplink(
                    code: .invalidPrefix,
                    string: "ethereum:0xdac17f958d2ee523a2206206994597c13d831ec7@137"
                )
            )
        }
    }
}
