@preconcurrency import BigInt
import ChainKit
@testable import KeeperCore
import OperationReviewModels
import XCTest

/// What a send of the wallet's own is reviewed as: chain-kit's `main` payload for it, under ids that
/// never change, and what the send is held to.
final class SignableOperationTransferTests: XCTestCase {
    private lazy var client = CryptoKitClient(
        netModule: ModuleNetModule(
            netConfig: ModuleNetConfig(isLogging: false, logger: nil, userAgent: nil, sessionProvider: nil, nodeManifestHost: nil)
        )
    )

    func test_aCoinSendIsChainKitsOwnMainPayloadUnderIdsThatNeverChange() async throws {
        let account = try account(.eth, Fixture.evmSender, holding: Fixture.eth)

        let signable = try await transfer(from: account, to: Fixture.evmRecipient, amount: 1_000_000_000)

        XCTAssertEqual(signable.operation.id, "transfer")
        let payload = try XCTUnwrap(signable.operation.payloads.first)
        XCTAssertEqual(signable.operation.payloads.count, 1)
        XCTAssertEqual(payload.id, "main")
        XCTAssertEqual(payload.type, Payload.Type_.main)
        XCTAssertEqual(payload.version, 1)
        XCTAssertNil(payload.fee)
        let meta = try XCTUnwrap(payload.meta as? PayloadMetaEvmMain)
        XCTAssertEqual(meta.to.display.lowercased(), Fixture.evmRecipient)
        XCTAssertEqual(meta.value.description, "1000000000")
        XCTAssertNil(meta.data)
        XCTAssertEqual(signable.fidelity, .converted)
        XCTAssertEqual(signable.account.asset.id, Fixture.eth.assetId)
        XCTAssertEqual(signable.intent, Fixture.intent)
    }

    func test_anERC20SendIsTheCallOfTheTokensContract() async throws {
        let account = try account(.eth, Fixture.evmSender, holding: Fixture.usdtERC20)

        let signable = try await transfer(from: account, to: Fixture.evmRecipient, amount: 1_000_000)

        let meta = try XCTUnwrap(signable.operation.payloads.first?.meta as? PayloadMetaEvmMain)
        XCTAssertEqual(meta.to.display.lowercased(), "0xdac17f958d2ee523a2206206994597c13d831ec7")
        XCTAssertEqual(meta.value.description, "0")
        XCTAssertEqual(
            meta.data?.lowercased(),
            "0xa9059cbb" + String(repeating: "0", count: 24) + Fixture.evmRecipient.dropFirst(2) + String(repeating: "0", count: 59) + "f4240"
        )
    }

    func test_aTRC20SendIsTheCallOfTheTokensContract() async throws {
        let account = try account(.tron, "TVdW9qX4kyXb9jFoUwXJswtEqKHdn85AVd", holding: Fixture.usdtTRC20)

        let signable = try await transfer(from: account, to: "TU1r33n75FL5dShBt13xcJfgBLuahLgTZo", amount: 3_000_000)

        let meta = try XCTUnwrap(signable.operation.payloads.first?.meta as? PayloadMetaTronMain)
        XCTAssertEqual(meta.to.display, "TR7NHqjeKQxGTCi8q8ZY4pL8otSzgjLj6t")
        XCTAssertEqual(meta.value.description, "0")
        XCTAssertEqual(meta.data?.hasPrefix("0xa9059cbb"), true)
    }

    func test_anSPLSendNamesItsMint() async throws {
        let account = try account(.sol, "9WzDXwBbmkg8ZTbNMqUxvQRAyrZzDsGYdLVL9zYtAWWM", holding: Fixture.usdcSPL)

        let signable = try await transfer(from: account, to: "EN2sCsJ1WDV8UFqsiTXHcUPUxQ4juE71eCknHYYMifkd", amount: 2_000_000)

        let meta = try XCTUnwrap(signable.operation.payloads.first?.meta as? PayloadMetaSolanaMain)
        XCTAssertEqual(meta.to.display, "EN2sCsJ1WDV8UFqsiTXHcUPUxQ4juE71eCknHYYMifkd")
        XCTAssertEqual(meta.token?.display, "EPjFWdd5AufqSSqeM2qN1xzybapC8G4wEGGkZwyTDt1v")
        XCTAssertEqual(meta.value.description, "2000000")
    }

    /// The whole balance goes as the send mode states it, so the payload is the same whatever the
    /// fee leaves.
    func test_aTonMaxSendCarriesTheWholeBalanceInMode128() async throws {
        let account = try account(.ton, Fixture.tonSender, type: .tonV4R2, holding: Fixture.ton)

        let signable = try await transfer(from: account, to: Fixture.tonRecipient, amount: 4_900_000_000, isMax: true)
        let fitted = try await transfer(from: account, to: Fixture.tonRecipient, amount: 4_800_000_000, isMax: true)

        let meta = try XCTUnwrap(signable.operation.payloads.first?.meta as? PayloadMetaTonMain)
        XCTAssertEqual(meta.mode?.intValue, 128)
        XCTAssertEqual(meta.value.description, "0")
        XCTAssertEqual(signable.operation.meta, fitted.operation.meta)
    }

    func test_theSameSendBuiltAgainIsTheSameReview() async throws {
        let account = try account(.eth, Fixture.evmSender, holding: Fixture.usdtERC20)
        let gate = OperationGate { [WarningCheck()] }

        let first = await gate.preview(.ask) { [self] in try await[transfer(from: account, to: Fixture.evmRecipient, amount: 1_000_000)] }
        let second = await gate.preview(.ask) { [self] in try await[transfer(from: account, to: Fixture.evmRecipient, amount: 1_000_000)] }
        let other = await gate.preview(.ask) { [self] in try await[transfer(from: account, to: Fixture.evmRecipient, amount: 1_000_001)] }

        XCTAssertNotNil(first)
        XCTAssertEqual(first?.id, second?.id)
        XCTAssertNotEqual(first?.id, other?.id)
    }

    func test_aRecipientChainKitCannotReadIsAnErrorRatherThanACrash() async throws {
        let account = try account(.eth, Fixture.evmSender, holding: Fixture.eth)

        do {
            _ = try await transfer(from: account, to: "not an address", amount: 1)
            XCTFail("expected the recipient to be refused")
        } catch {
            XCTAssertEqual(error as? ChainKitOperationError, .malformed("Ethereum recipient"))
        }
    }

    /// The fee a relayer takes in a token is held to the tolerance its re-quote is, with the token's
    /// own decimals.
    func test_aSendHoldsTheAmountConfirmedAndARelayerFeeToItsBound() {
        let intent = OperationIntent.send(
            1_000_000,
            of: Fixture.usdtERC20,
            to: Fixture.evmRecipient,
            fee: .relayerFee(115_304, in: Fixture.usdcERC20)
        )

        XCTAssertEqual(intent.spends, [OperationIntent.Spend(assetId: Fixture.usdtERC20.assetId, symbol: "USDT", decimals: 6, amount: 1_000_000)])
        XCTAssertEqual(intent.relayerFee, OperationIntent.Spend(assetId: Fixture.usdcERC20.assetId, symbol: "USDC", decimals: 6, amount: 121_069))
        XCTAssertEqual(intent.recipient, Fixture.evmRecipient)
        XCTAssertFalse(intent.isDapp)
    }
}

private extension SignableOperationTransferTests {
    func account(
        _ chain: MultichainChain,
        _ address: String,
        type: MultichainWalletAddressType? = nil,
        holding asset: MultichainAssetDetails
    ) throws -> ChainKit.Account {
        try ChainKitOperationSender.account(of: MultichainWalletAddress(chain: chain, address: address, type: type), holding: asset)
    }

    func transfer(
        from account: ChainKit.Account,
        to recipient: String,
        amount: BigUInt,
        isMax: Bool = false
    ) async throws -> SignableOperation {
        try await .transfer(
            from: account,
            to: recipient,
            amount: BignumBigInteger.Companion.shared.parseString(string: amount.description, base: 10),
            memo: nil,
            isMax: isMax,
            intent: Fixture.intent,
            fidelity: .converted,
            client: client
        )
    }
}

private enum Fixture {
    static let evmSender = "0x9858EfFD232B4033E47d90003D41EC34EcaEda94"
    static let evmRecipient = "0x8ba1f109551bd432803012645ac136ddd64dba72"
    static let tonSender = "UQBcmqkZxhc81WNeFFzq9ZX6qBlP28B-MuYeSxpS_-YMIDNl"
    static let tonRecipient = "EQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAM9c"

    static let eth = MultichainAssetDetails(assetId: "eth/mainnet/coin", name: "Ethereum", symbol: "ETH", decimals: 18, image: "")
    static let ton = MultichainAssetDetails(assetId: "ton/mainnet/coin", name: "Toncoin", symbol: "GRAM", decimals: 9, image: "")
    static let usdtERC20 = MultichainAssetDetails(
        assetId: "eth/mainnet/erc20/0xdac17f958d2ee523a2206206994597c13d831ec7",
        name: "Tether USD",
        symbol: "USDT",
        decimals: 6,
        image: ""
    )
    static let usdcERC20 = MultichainAssetDetails(
        assetId: "eth/mainnet/erc20/0xa0b86991c6218b36c1d19d4a2e9eb0ce3606eb48",
        name: "USD Coin",
        symbol: "USDC",
        decimals: 6,
        image: ""
    )
    static let usdtTRC20 = MultichainAssetDetails(
        assetId: "tron/mainnet/trc20/TR7NHqjeKQxGTCi8q8ZY4pL8otSzgjLj6t",
        name: "Tether USD",
        symbol: "USDT",
        decimals: 6,
        image: ""
    )
    static let usdcSPL = MultichainAssetDetails(
        assetId: "sol/mainnet/spl/EPjFWdd5AufqSSqeM2qN1xzybapC8G4wEGGkZwyTDt1v",
        name: "USD Coin",
        symbol: "USDC",
        decimals: 6,
        image: ""
    )

    static let intent = OperationIntent.send(1_000_000, of: usdtERC20, to: evmRecipient)
}
