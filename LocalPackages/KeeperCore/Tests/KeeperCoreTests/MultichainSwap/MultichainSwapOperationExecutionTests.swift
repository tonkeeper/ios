@preconcurrency import BigInt
@preconcurrency import ChainKit
import Foundation
@testable import KeeperCore
@testable import KeeperCoreComponents
import KeeperCoreSensitive
import OperationReviewModels
import TKBatteryAPI
import TonSwift
import XCTest

/// A swap quoted on `/v3/crosschain`, on Android's recorded responses: the route is prepared into the
/// operation the backend builds, priced payload by payload, reviewed before the passcode and signed as
/// it stands, at the fees its plan priced.
final class MultichainSwapOperationExecutionTests: XCTestCase {
    private static let tonUsdtRoute = "036bb244-764a-4cb0-b5b8-8e1362551794"
    private static let tonUsdtMessage = "63ff0764-ef20-4570-9877-1cbf3de61bd0"
    private static let omnistonRouter = "EQAH4MY1EbqP7Gg2wJkoZvoCG4BYPsEG5lVBXPZn0UqXNz4y"
    private static let swapsXyzRouter = "0x1b6257cae4192e62b629efca21771be3d759183d"
    private static let foreign = "EQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAM9c"
    private static let usdtEthereum = MultichainAssetDetails(
        assetId: "eth/mainnet/erc20/0xdac17f958d2ee523a2206206994597c13d831ec7",
        name: "Tether USD",
        symbol: "USDT",
        decimals: 6,
        image: ""
    )
    private static let usdtTron = MultichainAssetDetails(
        assetId: "tron/mainnet/trc20/TR7NHqjeKQxGTCi8q8ZY4pL8otSzgjLj6t",
        name: "Tether USD",
        symbol: "USDT",
        decimals: 6,
        image: ""
    )
    private static let usdtTon = MultichainAssetDetails(
        assetId: "ton/mainnet/jetton/0:b113a994b5024a16719f69139328eb759596c38a25f59028b146fecdc3621dfe",
        name: "Tether USD",
        symbol: "USDT",
        decimals: 6,
        image: ""
    )
    private static let usdcSolana = MultichainAssetDetails(
        assetId: "sol/mainnet/spl/EPjFWdd5AufqSSqeM2qN1xzybapC8G4wEGGkZwyTDt1v",
        name: "USD Coin",
        symbol: "USDC",
        decimals: 6,
        image: ""
    )
    private static let eth = MultichainAssetDetails(assetId: "eth/mainnet/coin", name: "Ethereum", symbol: "ETH", decimals: 18, image: "")
    private static let ton = MultichainAssetDetails(assetId: "ton/mainnet/coin", name: "Toncoin", symbol: "TON", decimals: 9, image: "")
    private static let sol = MultichainAssetDetails(assetId: "sol/mainnet/coin", name: "Solana", symbol: "SOL", decimals: 9, image: "")
    private static let trx = MultichainAssetDetails(assetId: "tron/mainnet/coin", name: "TRON", symbol: "TRX", decimals: 6, image: "")
    /// The router call of the recorded Ethereum route, the swap behind its approve.
    private static let routerCallPayload = "6626b85b-3990-4e43-8f54-6d7737fd8bf2"
    /// The recipient of the deposit of the recorded TRON route, as its calldata names it.
    private static let tronDepositRecipient = "TBKRnn4fMbcvtzm4XZqzbm2GrJJ6qmZyVG"
    /// The one payload of the recorded TRON route: USDT deposited by a TRC-20 transfer.
    private static let tronDeposit = "e317aa67-5a31-4a20-91a6-cf6099a5fb12"
    /// The one payload of the Ethereum route as swaps.xyz deposits the USDT sold: the token's `transfer`.
    private static let evmDeposit = "evm-deposit"
    /// The recipient of that deposit, as its calldata names it: the route names no deposit address.
    private static let evmDepositRecipient = "0x1111111111111111111111111111111111111111"
    /// The wallet's own USDT wallet on TON, which a sale of its USDT leaves by.
    private static let usdtTonWallet = "EQBjk4F8-Z0aK1JpASZgQme6NpbGJYQJ1h9dzb5Yp0yvmRkf"
    private static let battery = MultichainSwapFeeOption(cost: .batteryCharges(count: 3, excess: nil, isInsufficient: false))
    private static let gram = MultichainSwapFeeOption(cost: .gram(amountNano: 12_000_000, isInsufficient: false))

    private let clock = PaymentClock(ISO8601DateFormatter().date(from: "2026-11-02T15:50:00Z")!)
    private let pending = PendingTransactionsServiceFake()
    private var checks = [any OperationCheck]()

    // MARK: - Which API quotes a swap

    /// A registered wallet that signs with its own mnemonic swaps on `/v3` while the flag is on, unless it
    /// sells bitcoin, whose memo chain-kit drops. Any other wallet stays on `/v2`.
    func test_onlyARegisteredWalletOfItsOwnMnemonicSwapsOnV3AndNeverBitcoin() throws {
        let btc = MultichainAssetDetails(assetId: "btc/mainnet/coin", name: "Bitcoin", symbol: "BTC", decimals: 8, image: "")
        let key = PublicKey(data: Data(repeating: 1, count: 32))

        XCTAssertEqual(try swapWallet().swapAPIVersion(selling: Self.usdtEthereum, isV3Enabled: true), .v3)
        XCTAssertEqual(try swapWallet().swapAPIVersion(selling: Self.usdtEthereum, isV3Enabled: false), .v2)
        XCTAssertEqual(try swapWallet().swapAPIVersion(selling: btc, isV3Enabled: true), .v2)
        XCTAssertEqual(try swapWallet(keys: .device).swapAPIVersion(selling: Self.usdtEthereum, isV3Enabled: true), .v2)
        XCTAssertEqual(try swapWallet(keys: .legacy, registration: .unregistered).swapAPIVersion(selling: Self.ton, isV3Enabled: true), .v2)
        XCTAssertEqual(try swapWallet(registration: .unregistered).swapAPIVersion(selling: Self.ton, isV3Enabled: true), .v2)
        XCTAssertEqual(try swapWallet(kind: .SignerDevice(key, .v4R2)).swapAPIVersion(selling: Self.ton, isV3Enabled: true), .v2)
    }

    // MARK: - Which API prepares a route

    func test_aRouteQuotedOnV3IsPreparedOnV3AndNeverOnV2() async throws {
        let backend = try SwapBackend(answering: SwapFixture.prepare("ton_usdt"))
        let v2 = V2SwapServiceSpy()

        let plan = try await makeService(backend: backend, v2: v2).prepareExecutionPlan(
            swapWallet: swapWallet(),
            sourceAsset: asset(Self.ton),
            destinationAsset: asset(Self.usdtTon),
            route: quotedRoute("ton_usdt")
        )

        let paths = await backend.paths
        XCTAssertEqual(paths, ["/v3/crosschain/routes/\(Self.tonUsdtRoute)/prepare"])
        XCTAssertEqual(v2.prepareCount, 0)
        XCTAssertNoThrow(try operation(of: plan))
    }

    func test_aRouteQuotedOnV2IsPreparedOnV2AndNeverOnV3() async throws {
        let backend = try SwapBackend(answering: SwapFixture.prepare("ton_usdt"))
        let v2 = V2SwapServiceSpy()
        var route = try await quotedRoute("ton_usdt")
        route.apiVersion = .v2

        do {
            _ = try await makeService(backend: backend, v2: v2).prepareExecutionPlan(
                swapWallet: swapWallet(),
                sourceAsset: asset(Self.ton),
                destinationAsset: asset(Self.usdtTon),
                route: route
            )
            XCTFail("expected the v2 spy to refuse the prepare")
        } catch {}

        let paths = await backend.paths
        XCTAssertEqual(paths, [])
        XCTAssertEqual(v2.prepareCount, 1)
    }

    // MARK: - Prepare

    /// The swap screen's route is prepared into the backend's operation, one message to Omniston's
    /// router, priced as chain-kit prices it and shown as that operation receives.
    func test_theSwapScreensRouteIsPreparedIntoTheOperation() async throws {
        let steps = RecordedSwapOperationSteps()
        let route = try await quotedRoute("ton_usdt")

        let plan = try await makeService(backend: SwapBackend(answering: SwapFixture.prepare("ton_usdt")), steps: steps)
            .prepareExecutionPlan(swapWallet: swapWallet(), sourceAsset: asset(Self.ton), destinationAsset: asset(Self.usdtTon), route: route)

        let swap = try operation(of: plan)
        let message = try XCTUnwrap(swap.operation.payloads.first?.meta as? PayloadMetaTonMain)
        XCTAssertEqual(swap.operation.payloads.count, 1)
        XCTAssertEqual(message.to.display, Self.omnistonRouter)
        XCTAssertEqual(message.value.description, "1280000000")
        XCTAssertEqual(plan.networkFees.map(\.fee), [21000])
        XCTAssertEqual(plan.networkFees.map(\.asset.assetId), [Self.ton.assetId])
        XCTAssertEqual(plan.feeOptions.map(\.method), [.native])
        XCTAssertEqual(plan.preparedRoute?.estimatedDestinationAmount, "1183456")
        XCTAssertEqual(plan.sourceAmount, route.sourceAmount)
        XCTAssertEqual(swap.expiresAt, ISO8601DateFormatter().date(from: "2026-11-02T15:50:26Z"))
        let took = await steps.steps
        XCTAssertEqual(took, try [
            .price(payload: Self.tonUsdtMessage, address: tonAddress(), asset: Self.ton.assetId),
            .cover(amount: "1280000000", fee: "21000", address: tonAddress(), asset: Self.ton.assetId),
        ])
    }

    /// The swap behind an approve spends the allowance the approve has yet to grant: it is priced at the
    /// chain's default fee, never simulated. The approve keeps the gas the route quotes.
    func test_anEVMTokenSwapIsPricedAtTheDefaultFeeBehindItsApprove() async throws {
        let steps = RecordedSwapOperationSteps()

        let plan = try await makeService(backend: SwapBackend(answering: SwapFixture.prepare("usdteth_eth")), steps: steps).prepareExecutionPlan(
            swapWallet: swapWallet(),
            sourceAsset: asset(Self.usdtEthereum),
            destinationAsset: asset(Self.eth),
            route: quotedRoute("usdteth_eth")
        )

        let swap = try operation(of: plan)
        let (approve, router) = (swap.operation.payloads[0], swap.operation.payloads[1])
        let took = await steps.steps
        let sender = try ethAddress()
        XCTAssertEqual(took, [
            .price(payload: approve.id, address: sender, asset: Self.eth.assetId),
            .defaultPrice(payload: router.id, address: sender, asset: Self.eth.assetId),
            .cover(amount: "0", fee: "200026129478127", address: sender, asset: Self.eth.assetId),
        ])
        // The approve quotes its gas: 63617 at 301418031 wei.
        XCTAssertEqual(swap.fees.map(\.amount.description), ["19175310878127", "180850818600000"])
        XCTAssertEqual(plan.networkFees.map(\.fee), [BigUInt(200_026_129_478_127)])
        XCTAssertEqual(swap.account.asset.id, Self.usdtEthereum.assetId)
        XCTAssertEqual(swap.signingAccount.asset.id, Self.eth.assetId)
        XCTAssertEqual(swap.recipient?.lowercased(), Self.swapsXyzRouter)
        XCTAssertEqual(plan.preparedRoute?.estimatedDestinationAmount, "8673111496476925")
        XCTAssertEqual(plan.preparedRoute?.minimumDestinationAmount, "8586380381512155")
        XCTAssertEqual(plan.providerRouteId, "0xf4a6c7d60c9852471d571261da4cc5c9da056120aaf8edec34371b6b09967d0c")
    }

    /// A Solana token moves out of its own account, which chain-kit signs it from.
    func test_aSolanaTokenSaleIsSignedFromTheTokensAccount() async throws {
        let prepared = try SwapFixture.prepare("ton_usdt", payload: { $0["chain_id"] = "sol/mainnet" }, meta: {
            $0 = ["to": "9WzDXwBbmkg8ZTbNMqUxvQRAyrZzDsGYdLVL9zYtAWWM", "value": "1000000", "token": "EPjFWdd5AufqSSqeM2qN1xzybapC8G4wEGGkZwyTDt1v"]
        })

        let plan = try await makeService(backend: SwapBackend(answering: prepared)).prepareExecutionPlan(
            swapWallet: swapWallet(),
            sourceAsset: asset(Self.usdcSolana),
            destinationAsset: asset(Self.ton),
            route: quotedRoute("ton_usdt")
        )

        let swap = try operation(of: plan)
        XCTAssertEqual(swap.signingAccount.asset.id, Self.usdcSolana.assetId)
        XCTAssertEqual(swap.account.asset.id, Self.usdcSolana.assetId)
    }

    /// Only a swap behind its approve on EVM takes the chain's default fee: a router call alone is priced
    /// as chain-kit prices it, and the coin it sends is held to the balance with its fee.
    func test_aLoneEVMPayloadWithNoFeeIsPricedAndTheCoinItSendsHeld() async throws {
        let steps = RecordedSwapOperationSteps()
        let prepared = try SwapFixture.prepare(
            "usdteth_eth",
            operation: { $0["payloads"] = Array(($0["payloads"] as? [[String: Any]] ?? []).suffix(1)) },
            meta: { $0["value"] = "500000000000000000" }
        )

        _ = try await makeService(backend: SwapBackend(answering: prepared), steps: steps).prepareExecutionPlan(
            swapWallet: swapWallet(),
            sourceAsset: asset(Self.eth),
            destinationAsset: asset(Self.usdtEthereum),
            route: quotedRoute("usdteth_eth")
        )

        let took = await steps.steps
        XCTAssertEqual(took, try [
            .price(payload: "6626b85b-3990-4e43-8f54-6d7737fd8bf2", address: ethAddress(), asset: Self.eth.assetId),
            .cover(amount: "500000000000000000", fee: "21000", address: ethAddress(), asset: Self.eth.assetId),
        ])
    }

    /// Off EVM a payload behind another is priced as chain-kit prices it, and the coin each sends is held
    /// to the balance.
    func test_aTRONPayloadBehindAnotherIsPricedAndTheCoinBothSendHeld() async throws {
        let steps = RecordedSwapOperationSteps()
        let prepared = try SwapFixture.prepare(
            "usdttron_ton",
            operation: { operation in
                let payloads = operation["payloads"] as? [[String: Any]] ?? []
                var first = payloads.first ?? [:]
                first["id"] = "first"
                operation["payloads"] = [first] + payloads
            },
            meta: { $0["value"] = "1000000" }
        )

        _ = try await makeService(backend: SwapBackend(answering: prepared), steps: steps).prepareExecutionPlan(
            swapWallet: swapWallet(),
            sourceAsset: asset(Self.usdtTron),
            destinationAsset: asset(Self.ton),
            route: quotedRoute("usdttron_ton")
        )

        let took = await steps.steps
        let sender = try walletAddress(.tron).address.lowercased()
        XCTAssertEqual(took, [
            .price(payload: "first", address: sender, asset: "tron/mainnet/coin"),
            .price(payload: "e317aa67-5a31-4a20-91a6-cf6099a5fb12", address: sender, asset: "tron/mainnet/coin"),
            .cover(amount: "2000000", fee: "42000", address: sender, asset: "tron/mainnet/coin"),
        ])
    }

    /// A sale of Solana's coin is held to the coin its payload sends.
    func test_aSolanaCoinSaleIsHeldToTheCoinItSends() async throws {
        let steps = RecordedSwapOperationSteps()
        let prepared = try SwapFixture.prepare("ton_usdt", payload: { $0["chain_id"] = "sol/mainnet" }, meta: {
            $0 = ["to": "9WzDXwBbmkg8ZTbNMqUxvQRAyrZzDsGYdLVL9zYtAWWM", "value": "1000000"]
        })

        _ = try await makeService(backend: SwapBackend(answering: prepared), steps: steps).prepareExecutionPlan(
            swapWallet: swapWallet(),
            sourceAsset: asset(Self.sol),
            destinationAsset: asset(Self.ton),
            route: quotedRoute("ton_usdt")
        )

        let took = await steps.steps
        let sender = try walletAddress(.sol).address.lowercased()
        XCTAssertEqual(took, [
            .price(payload: Self.tonUsdtMessage, address: sender, asset: Self.sol.assetId),
            .cover(amount: "1000000", fee: "21000", address: sender, asset: Self.sol.assetId),
        ])
    }

    func test_feesInMoreThanOneAssetCannotBeSwapped() async {
        let steps = RecordedSwapOperationSteps(defaultPrice: { _, _ in
            FeeValue(asset: MultichainChain.base.asChainKitChain.toAsset(), amount: BignumBigInteger(long: 1))
        })

        let failure = await preparationFailure(of: "usdteth_eth", selling: Self.usdtEthereum, steps: steps)

        guard case .preparationFailed(.unsupportedTransaction, _) = failure else {
            return XCTFail("expected a route that cannot be swapped, got \(String(describing: failure))")
        }
    }

    /// The coin has to cover what the payloads send and their fee: short of that, the shortage is the one
    /// the confirmation offers a deposit for, and nothing is trimmed to fit. The swap screen holds the
    /// TON sold to the balance, so the shortage is the fee and the gas the route forwards beside it.
    func test_aCoinShortOfWhatTheSwapSendsAndItsFeeIsAShortage() async {
        let failure = await preparationFailure(of: "ton_usdt", selling: Self.ton, steps: RecordedSwapOperationSteps(coinCovers: false))

        guard case let .insufficientNativeFee(shortage) = failure else {
            return XCTFail("expected the coin to fall short, got \(String(describing: failure))")
        }
        XCTAssertEqual(shortage.asset.assetId, Self.ton.assetId)
        // The message sends 1.28 TON for the 1 TON sold.
        XCTAssertEqual(shortage.requiredAmount, 280_021_000)
    }

    /// The coin chain-kit attaches to the transfer of a jetton it deposits is held to the balance with the
    /// fee: a wallet without it would pay the fee for a transfer the action phase drops.
    func test_aJettonDepositIsShortOfTheCoinItsTransferCarries() async throws {
        let steps = RecordedSwapOperationSteps(coinCovers: false)

        let failure = try await preparationFailure(
            of: "ton_usdt",
            answering: SwapFixture.prepare("ton_usdt", meta: Self.jettonDeposit),
            selling: Self.usdtTon,
            steps: steps
        )

        guard case let .insufficientNativeFee(shortage) = failure else {
            return XCTFail("expected the coin to fall short, got \(String(describing: failure))")
        }
        XCTAssertEqual(shortage.asset.assetId, Self.ton.assetId)
        XCTAssertEqual(shortage.requiredAmount, 80_021_001)
        let took = await steps.steps
        XCTAssertEqual(took.last, try .cover(amount: "80000001", fee: "21000", address: tonAddress(), asset: Self.ton.assetId))
    }

    /// A payload chain-kit could not price, as one emulated on a wallet without the coin to send it, is put
    /// to the balance at the chain's default fee: short of that, the shortage is what the swap shows.
    func test_aPayloadChainKitCannotPriceOnAWalletShortOfTheCoinIsAShortage() async throws {
        let steps = RecordedSwapOperationSteps(price: Self.refusedPrice, defaultPrice: Self.tonDefaultFee, coinCovers: false)

        let failure = await preparationFailure(of: "ton_usdt", selling: Self.ton, steps: steps)

        guard case let .insufficientNativeFee(shortage) = failure else {
            return XCTFail("expected the coin to fall short, got \(String(describing: failure))")
        }
        XCTAssertEqual(shortage.requiredAmount, 285_500_000)
        let took = await steps.steps
        XCTAssertEqual(took, try [
            .price(payload: Self.tonUsdtMessage, address: tonAddress(), asset: Self.ton.assetId),
            .defaultPrice(payload: Self.tonUsdtMessage, address: tonAddress(), asset: Self.ton.assetId),
            .cover(amount: "1280000000", fee: "5500000", address: tonAddress(), asset: Self.ton.assetId),
        ])
    }

    /// Where the balance covers the payload at the chain's default fee, its own failure is what the swap shows.
    func test_aPayloadChainKitCannotPriceKeepsItsFailureWhereTheCoinCovers() async {
        let failure = await preparationFailure(
            of: "ton_usdt",
            selling: Self.ton,
            steps: RecordedSwapOperationSteps(price: Self.refusedPrice, defaultPrice: Self.tonDefaultFee)
        )

        XCTAssertEqual(failure, .emulationFailed(kind: .unknown, reason: "refused"))
    }

    /// chain-kit builds no default fee for a jetton deposit from the coin's account: the deposit is held to
    /// the coin its transfer carries, which proves a shortage without inventing one.
    func test_aJettonDepositChainKitCannotPriceIsHeldToTheCoinItsTransferCarries() async throws {
        let steps = RecordedSwapOperationSteps(
            price: Self.refusedPrice,
            defaultPrice: Self.unboundPrice,
            coinCovers: false
        )

        let failure = try await preparationFailure(
            of: "ton_usdt",
            answering: SwapFixture.prepare("ton_usdt", meta: Self.jettonDeposit),
            selling: Self.usdtTon,
            steps: steps
        )

        guard case let .insufficientNativeFee(shortage) = failure else {
            return XCTFail("expected the coin to fall short, got \(String(describing: failure))")
        }
        XCTAssertEqual(shortage.requiredAmount, 80_000_001)
        let took = await steps.steps
        XCTAssertEqual(took.last, try .cover(amount: "80000001", fee: "0", address: tonAddress(), asset: Self.ton.assetId))
    }

    func test_aRouteItsValidationRejectedCannotBeSwapped() async throws {
        let failure = try await preparationFailure(answering: SwapFixture.prepare("ton_usdt", root: { $0["validation_status"] = "rejected" }))

        guard case .preparationFailed(.unsupportedTransaction, _) = failure else {
            return XCTFail("expected a route that cannot be swapped, got \(String(describing: failure))")
        }
    }

    func test_anOperationThatDoesNotParseCannotBeSwapped() async throws {
        let failure = try await preparationFailure(answering: SwapFixture.prepare("ton_usdt", payload: { $0["chain_id"] = "nowhere/mainnet" }))

        guard case .preparationFailed(.unsupportedTransaction, _) = failure else {
            return XCTFail("expected a route that cannot be swapped, got \(String(describing: failure))")
        }
    }

    /// A route still being validated may pass as a fresh one: its failure is one the confirmation quotes
    /// and prepares again for.
    func test_aRouteStillBeingValidatedIsQuotedAndPreparedAgain() async throws {
        let failure = try await preparationFailure(answering: SwapFixture.prepare("ton_usdt", root: { $0["validation_status"] = "pending" }))

        XCTAssertEqual(failure, .payloadNotValidated(payloadId: Self.tonUsdtRoute, status: "pending"))
    }

    func test_aPrepareAnsweredForAnotherRouteIsABadResponse() async throws {
        let steps = RecordedSwapOperationSteps()

        let failure = try await preparationFailure(answering: SwapFixture.prepare("ton_usdt", root: { $0["route_id"] = "another-route" }), steps: steps)

        guard case .preparationFailed(.badResponse, _) = failure else {
            return XCTFail("expected a bad response, got \(String(describing: failure))")
        }
        let took = await steps.steps
        XCTAssertEqual(took, [])
    }

    func test_payloadsOnAnotherChainThanTheAssetSoldCannotBeSwapped() async throws {
        let steps = RecordedSwapOperationSteps()

        let failure = try await preparationFailure(
            answering: SwapFixture.prepare("usdteth_eth", root: { $0["route_id"] = Self.tonUsdtRoute }),
            steps: steps
        )

        guard case .preparationFailed(.unsupportedTransaction, _) = failure else {
            return XCTFail("expected a route that cannot be swapped, got \(String(describing: failure))")
        }
        let took = await steps.steps
        XCTAssertEqual(took, [])
    }

    func test_aScreenedWalletIsToldSoAsOnV2() async {
        let failure = await preparationFailure(
            backend: SwapBackend(answers: [(.badRequest, Data(#"{"error":"wallet screened","code":"wallet_screened","request_id":"request-1"}"#.utf8))])
        )

        guard case .preparationFailed(.walletScreened, _) = failure else {
            return XCTFail("expected a screened wallet, got \(String(describing: failure))")
        }
    }

    // MARK: - What the review holds a swap to

    /// A DEX swap is held to what it sells: the router it calls comes from the same answer as the
    /// operation, so the review does not name it.
    func test_aDexSwapIsHeldToItsAmountAlone() async throws {
        let check = WarningCheck()
        checks = [check]

        try await execute("ton_usdt", selling: Self.ton, buying: Self.usdtTon, spendLimit: 1_000_000_000)

        let reads = await check.reads.all
        XCTAssertEqual(reads.map(\.intent), [.send(1_000_000_000, of: Self.ton, to: nil)])
        XCTAssertEqual(reads.map(\.assetId), [Self.ton.assetId])
    }

    /// A TRC-20 transfer names its recipient in its calldata: the review names no contract for it.
    func test_aTokenDepositNamesNoContract() async throws {
        let check = WarningCheck()
        checks = [check]

        try await execute("usdttron_ton", selling: Self.usdtTron, buying: Self.ton, spendLimit: 20_000_000)

        let reads = await check.reads.all
        XCTAssertEqual(reads.map(\.intent), [.send(20_000_000, of: Self.usdtTron, to: nil)])
        XCTAssertEqual(reads.map(\.assetId), [Self.usdtTron.assetId])
    }

    /// A token's deposit on an EVM chain is the token's `transfer`, which names the deposit address
    /// itself: held to no contract, chain-kit finds nothing in it, and the swap goes out unasked.
    func test_anEVMTokenDepositIsHeldToNoContractAndSentUnasked() async throws {
        checks = [ChainKitValidationCheck(client: CryptoKitClient(
            netModule: ModuleNetModule(netConfig: ModuleNetConfig(isLogging: false, logger: nil, userAgent: nil, sessionProvider: nil, nodeManifestHost: nil))
        ))]
        let user = ConsentingUser(answering: true)

        let result = try await execute(
            "usdteth_eth",
            answering: Self.evmTokenDeposit(),
            selling: Self.usdtEthereum,
            buying: Self.eth,
            spendLimit: 20_000_000,
            consent: user.attempt()
        )

        let asked = await user.asked
        XCTAssertEqual(asked.flatMap(\.findings), [])
        XCTAssertEqual(result.txHash, "0x\(Self.evmDeposit)")
    }

    /// A jetton sold through a router leaves by the transfer the wallet's own wallet of it makes to the
    /// router, which names its recipient itself: the review names no contract for it, not that wallet.
    func test_aJettonSoldThroughARouterNamesNoContract() async throws {
        let check = WarningCheck()
        checks = [check]

        try await execute("ton_usdt", answering: jettonSale(), selling: Self.usdtTon, buying: Self.ton, spendLimit: 1_000_000)

        let reads = await check.reads.all
        XCTAssertEqual(reads.map(\.intent), [.send(1_000_000, of: Self.usdtTon, to: nil)])
    }

    /// A TON swap runs through the first of its messages that calls a contract. A jetton's transfer
    /// calls none: the wallet's own wallet of the jetton makes it to the address it names. A body that
    /// does not parse is read as a call.
    func test_aTonSwapRunsThroughTheFirstMessageThatCallsAContract() throws {
        let transfer = try jettonTransfer(to: Self.omnistonRouter)
        // The op of the recorded swap's message to Omniston's router.
        let routerCall = try Builder().store(uint: UInt32(0xA5A7_CBF8), bits: 32).endCell().toBoc().base64EncodedString()
        func message(to: String, body: String) -> String {
            #"{"to":"\#(to)","value":"300000000","body":"\#(body)"}"#
        }
        func batch(_ messages: [String]) -> String {
            let calls = messages.map { #"{"type":"main","meta":\#($0)}"# }
            return #"{"calls":[\#(calls.joined(separator: ","))]}"#
        }
        let cases: [(shape: String, type: String, meta: String, contract: String?)] = [
            ("a jetton's transfer", "main", message(to: Self.usdtTonWallet, body: transfer), nil),
            ("a body that does not parse", "main", message(to: Self.usdtTonWallet, body: "ton-payload"), Self.usdtTonWallet),
            (
                "a router call behind a jetton's transfer",
                "batch",
                batch([message(to: Self.usdtTonWallet, body: transfer), message(to: Self.omnistonRouter, body: routerCall)]),
                Self.omnistonRouter
            ),
            ("jettons' transfers alone", "batch", batch([message(to: Self.usdtTonWallet, body: transfer), message(to: Self.usdtTonWallet, body: transfer)]), nil),
        ]

        for (shape, type, meta, contract) in cases {
            let operation = try ChainKitOperationSender.parse(
                id: "route",
                payloads: #"[{"chain_id":"ton/mainnet","id":"swap","type":"\#(type)","version":1,"meta":\#(meta)}]"#
            )
            XCTAssertEqual(operation.calledContract, contract, shape)
        }
    }

    /// A jetton deposit moves the jetton it names and calls no contract; the coin chain-kit attaches to its
    /// transfer is held to the balance with the fee.
    func test_aTonJettonDepositKeepsItsTokenAndNamesNoContract() async throws {
        let check = WarningCheck()
        checks = [check]
        let steps = RecordedSwapOperationSteps()
        let prepared = try SwapFixture.prepare("ton_usdt", meta: Self.jettonDeposit)

        try await execute("ton_usdt", answering: prepared, selling: Self.usdtTon, buying: Self.ton, spendLimit: 1_000_000, steps: steps)

        let reads = await check.reads.all
        XCTAssertEqual(reads.map(\.intent), [.send(1_000_000, of: Self.usdtTon, to: nil)])
        let took = await steps.steps
        XCTAssertTrue(try took.contains(.cover(amount: "80000001", fee: "21000", address: tonAddress(), asset: Self.ton.assetId)), "\(took)")
    }

    /// The deposit address comes from the same answer as the operation: the review does not name it.
    func test_aDepositAddressTheRouteNamesIsNotTheRecipient() async throws {
        let deposit = "TJRabPrwbZy45sbavfcjinPJC18kjpRTv8"
        let check = WarningCheck()
        checks = [check]
        let prepared = try SwapFixture.prepare("usdttron_ton", summary: { $0["deposit_address"] = deposit })

        try await execute("usdttron_ton", answering: prepared, selling: Self.usdtTron, buying: Self.ton, spendLimit: 20_000_000)

        let reads = await check.reads.all
        XCTAssertEqual(reads.map(\.intent.recipient), [nil])
    }

    // MARK: - Asking

    /// A danger chain-kit finds is put to the user before the passcode: refused, nothing is unlocked,
    /// signed or sent.
    func test_aDangerIsAskedAboutBeforeThePasscodeAndARefusalSignsNothing() async throws {
        checks = [Verdict { ValidationError.ForeignRecipient(payloadId: $0.operation.id, expected: Self.omnistonRouter, actual: Self.foreign) }]
        let user = ConsentingUser(answering: false)
        let steps = RecordedSwapOperationSteps()

        do {
            try await execute("ton_usdt", selling: Self.ton, buying: Self.usdtTon, consent: user.attempt(), steps: steps)
            XCTFail("expected the refusal to cancel the swap")
        } catch {
            XCTAssertEqual(error as? MultichainSwapExecutionFailure, .canceled)
        }

        let asked = await user.asked
        XCTAssertEqual(asked.flatMap(\.findings).map(\.severity), [.danger])
        let took = await steps.steps
        XCTAssertFalse(took.contains(.unlock), "\(took)")
        let reported = await pending.reported
        XCTAssertEqual(reported, [])
    }

    func test_aDangerTheUserAcceptsIsUnlockedForAndSent() async throws {
        checks = [Verdict { ValidationError.ForeignRecipient(payloadId: $0.operation.id, expected: Self.omnistonRouter, actual: Self.foreign) }]
        let user = ConsentingUser(answering: true)

        let result = try await execute("ton_usdt", selling: Self.ton, buying: Self.usdtTon, consent: user.attempt())

        let asked = await user.asked
        XCTAssertEqual(asked.count, 1)
        XCTAssertEqual(result.txHash, "0x\(Self.tonUsdtMessage)")
    }

    /// What chain-kit rates a warning is information in the wallet's own swap: nobody is asked.
    func test_aWarningAsksNothingInTheWalletsOwnSwap() async throws {
        checks = [Verdict { ValidationError.UnlistedAsset(payloadId: $0.operation.id, asset: Self.usdtTon.assetId, amount: nil, to: nil, approved: false) }]
        let user = ConsentingUser(answering: false)

        let result = try await execute("ton_usdt", selling: Self.ton, buying: Self.usdtTon, consent: user.attempt())

        let asked = await user.asked
        XCTAssertEqual(asked, [])
        XCTAssertEqual(result.txHash, "0x\(Self.tonUsdtMessage)")
    }

    func test_anOperationNoCheckCouldReadIsNeitherUnlockedForNorSent() async throws {
        checks = [FailingCheck()]
        let steps = RecordedSwapOperationSteps()

        do {
            try await execute("ton_usdt", selling: Self.ton, buying: Self.usdtTon, steps: steps)
            XCTFail("expected the unreviewed swap to fail")
        } catch {
            guard case .internal = error as? MultichainSwapExecutionFailure else {
                return XCTFail("expected an internal failure, got \(error)")
            }
        }
        let took = await steps.steps
        XCTAssertFalse(took.contains(.unlock), "\(took)")
    }

    // MARK: - Sending

    /// The approve goes out ahead of the swap, each at the very fee the plan priced it at, from the
    /// chain's account with the unlocked key; only the swap is reported, as one, under its own hash.
    func test_theApproveGoesOutAheadOfTheSwapAtTheFeesShownAndOnlyTheSwapIsReported() async throws {
        let steps = RecordedSwapOperationSteps()
        let approve = "62f4f101-9be6-4400-a671-eb6caa5f5332"
        let swap = "6626b85b-3990-4e43-8f54-6d7737fd8bf2"

        let result = try await execute("usdteth_eth", selling: Self.usdtEthereum, buying: Self.eth, spendLimit: 20_000_000, steps: steps)

        let took = await steps.steps
        let priced = await steps.priced
        let key = try RecordedSwapOperationSteps.unlocked().getPublicKey(chain: MultichainChain.eth.asChainKitChain).defaultHex
        // Priced once, by the plan: nothing is priced again on the way to the signature.
        XCTAssertEqual(took, try [
            .price(payload: approve, address: ethAddress(), asset: Self.eth.assetId),
            .defaultPrice(payload: swap, address: ethAddress(), asset: Self.eth.assetId),
            .cover(amount: "0", fee: "200026129478127", address: ethAddress(), asset: Self.eth.assetId),
            .unlock,
            .send(
                operation: "9462c7d9-637c-460e-8a36-a883c00b6f40",
                payloads: [approve, swap],
                address: ethAddress(),
                asset: Self.eth.assetId,
                key: key,
                fees: [XCTUnwrap(priced[approve]), XCTUnwrap(priced[swap])],
                expiresAt: XCTUnwrap(ISO8601DateFormatter().date(from: "2026-11-02T15:50:42Z"))
            ),
        ])
        XCTAssertEqual(result.txHash, "0x\(swap)")
        XCTAssertEqual(result.broadcastedPayloads.map(\.payloadId), [approve, swap])
        XCTAssertEqual(result.broadcastedPayloads.map(\.kind), ["approval", "main"])
        let reported = await pending.reported
        XCTAssertEqual(reported, try [
            MultichainPendingTransaction(
                walletId: "wallet-1",
                chain: .eth,
                network: .mainnet,
                txHash: "0x\(swap)",
                activityType: .swap(
                    MultichainPendingTransaction.SwapDetails(
                        fromAssetId: Self.usdtEthereum.assetId,
                        toAssetId: Self.eth.assetId,
                        fromAddress: walletAddress(.eth).address,
                        fromAmount: "20000000",
                        quote: .init(
                            aggregator: "swapsxyz",
                            routeId: "9462c7d9-637c-460e-8a36-a883c00b6f40",
                            providerRouteId: "0xf4a6c7d60c9852471d571261da4cc5c9da056120aaf8edec34371b6b09967d0c"
                        )
                    )
                )
            ),
        ])
    }

    /// The passcode can outlast the route: once it has, nothing is signed or sent, and the failure is the
    /// expired route the confirmation quotes again for.
    func test_aRouteThatExpiredBehindThePasscodeIsNotSent() async throws {
        let clock = clock
        let steps = RecordedSwapOperationSteps(onUnlock: { clock.advance(by: 26) })

        do {
            try await execute("ton_usdt", selling: Self.ton, buying: Self.usdtTon, steps: steps)
            XCTFail("expected the expired route to stop the swap")
        } catch {
            XCTAssertEqual(error as? MultichainSwapExecutionFailure, .routeExpired(routeId: Self.tonUsdtRoute))
        }

        let took = await steps.steps
        XCTAssertEqual(took.last, .unlock)
        let reported = await pending.reported
        XCTAssertEqual(reported, [])
    }

    /// A route that expired before the swap was confirmed is neither reviewed nor unlocked for.
    func test_aRouteThatExpiredBeforeItsReviewIsNeitherReviewedNorUnlocked() async throws {
        let check = WarningCheck()
        checks = [check]
        let steps = RecordedSwapOperationSteps()
        let service = try makeService(backend: SwapBackend(answering: SwapFixture.prepare("ton_usdt")), steps: steps)
        let plan = try await service.prepareExecutionPlan(
            swapWallet: swapWallet(),
            sourceAsset: asset(Self.ton),
            destinationAsset: asset(Self.usdtTon),
            route: quotedRoute("ton_usdt")
        )
        clock.advance(by: 26)

        do {
            _ = try await service.execute(
                signer: .mnemonic(passcodeProvider: { "passcode" }),
                swapWallet: swapWallet(),
                sourceAsset: asset(Self.ton),
                destinationAsset: asset(Self.usdtTon),
                executionPlan: plan,
                feeMethod: .native,
                spendLimit: 1_000_000_000,
                consent: ConsentingUser(answering: true).attempt()
            )
            XCTFail("expected the expired route to stop the swap")
        } catch {
            XCTAssertEqual(error as? MultichainSwapExecutionFailure, .routeExpired(routeId: Self.tonUsdtRoute))
        }

        let reads = await check.reads.all
        XCTAssertEqual(reads, [])
        let took = await steps.steps
        XCTAssertFalse(took.contains(.unlock), "\(took)")
    }

    /// A fee method the plan of a route `/v3` prepared does not offer signs nothing, as on `/v2`, even
    /// where the plan offers another relayed one.
    func test_aFeeMethodTheV3PlanDoesNotOfferSignsNothing() async throws {
        let ton = RelayEngineSpy(chain: .ton, offering: [Self.battery])
        let plan = try await preparePlan("ton_usdt", selling: Self.ton, buying: Self.usdtTon, engines: [ton])
        let steps = RecordedSwapOperationSteps()

        XCTAssertEqual(plan.feeOptions.map(\.method), [.battery, .native])
        do {
            _ = try await makeService(backend: SwapBackend(), steps: steps, engines: [ton]).execute(
                signer: .mnemonic(passcodeProvider: { "passcode" }),
                swapWallet: swapWallet(),
                sourceAsset: asset(Self.ton),
                destinationAsset: asset(Self.usdtTon),
                executionPlan: plan,
                feeMethod: .gram,
                spendLimit: 1_000_000_000,
                consent: ConsentingUser(answering: true).attempt()
            )
            XCTFail("expected GRAM to be refused")
        } catch {
            guard case .internal = error as? MultichainSwapExecutionFailure else {
                return XCTFail("expected an internal failure, got \(error)")
            }
        }
        let took = await steps.steps
        XCTAssertEqual(took, [])
        XCTAssertTrue(ton.prepared.isEmpty)
    }

    /// A send that fails is the swap's failure: nothing is reported as pending.
    func test_aSendThatFailsReportsNothing() async throws {
        let refusal = MultichainSwapExecutionFailure.broadcastFailed(payloadId: Self.tonUsdtMessage, kind: .insufficientBalance, reason: "refused")

        do {
            try await execute("ton_usdt", selling: Self.ton, buying: Self.usdtTon, steps: RecordedSwapOperationSteps(sendFailure: refusal))
            XCTFail("expected the refused send to fail the swap")
        } catch {
            XCTAssertEqual(error as? MultichainSwapExecutionFailure, refusal)
        }

        let reported = await pending.reported
        XCTAssertEqual(reported, [])
    }

    /// The passcode released the swap: closing the screen no longer stops it, as it does not stop a send.
    func test_aSwapThePasscodeReleasedGoesOutWhenTheScreenCloses() async throws {
        let steps = RecordedSwapOperationSteps(onUnlock: {
            _ = withUnsafeCurrentTask { $0?.cancel() }
        })

        let sending = Task { try await execute("ton_usdt", selling: Self.ton, buying: Self.usdtTon, steps: steps) }
        let result = try await sending.value

        XCTAssertEqual(result.txHash, "0x\(Self.tonUsdtMessage)")
    }

    func test_onlyTheWalletsMnemonicSignsARoutePreparedOnV3() async throws {
        let plan = try await makeService(backend: SwapBackend(answering: SwapFixture.prepare("ton_usdt"))).prepareExecutionPlan(
            swapWallet: swapWallet(),
            sourceAsset: asset(Self.ton),
            destinationAsset: asset(Self.usdtTon),
            route: quotedRoute("ton_usdt")
        )
        let steps = RecordedSwapOperationSteps()
        let user = ConsentingUser(answering: true)

        do {
            _ = try await makeService(backend: SwapBackend(), steps: steps).execute(
                signer: .device(Self.device),
                swapWallet: swapWallet(keys: .device),
                sourceAsset: asset(Self.ton),
                destinationAsset: asset(Self.usdtTon),
                executionPlan: plan,
                feeMethod: .native,
                spendLimit: 1_000_000_000,
                consent: user.attempt()
            )
            XCTFail("expected a hardware wallet to be refused")
        } catch {
            guard case .internal = error as? MultichainSwapExecutionFailure else {
                return XCTFail("expected an internal failure, got \(error)")
            }
        }
        let took = await steps.steps
        XCTAssertEqual(took, [])
    }

    // MARK: - Relayed fee methods

    /// A router call alone is priced by the EVM relayer as the payload's call, and the battery and the
    /// token it quotes are offered beside the coin. Behind its approve the swap is paid in the coin
    /// alone, as on `/v2`.
    func test_anEVMRouterCallIsQuotedByTheRelayerAsItsCallAndNotBehindItsApprove() async throws {
        let estimations = [
            EVMGaslessEstimation(asset: .init(id: AssetBattery.Companion.shared.ID, name: "Battery", symbol: "BATTERY", decimals: 0, image: nil), fee: 18, isAvailable: true),
            EVMGaslessEstimation(asset: .init(id: Self.usdtEthereum.assetId, name: "Tether", symbol: "USDT", decimals: 6, image: nil), fee: 115_304, isAvailable: true),
        ]
        let relayer = QuotingRelayer(estimations: estimations)

        let plan = try await preparePlan("usdteth_eth", answering: Self.routerCall(), selling: Self.usdtEthereum, buying: Self.eth, engines: [evmEngine(relayer)])

        XCTAssertEqual(plan.feeOptions.map(\.method), [.battery, .token(assetId: Self.usdtEthereum.assetId), .native])
        XCTAssertFalse(plan.requiresApproval)
        let router = try XCTUnwrap(operation(of: plan).operation.payloads.last?.meta as? PayloadMetaEvmMain)
        let quoted = await relayer.quoted
        XCTAssertEqual(quoted, try [
            EVMGaslessCall(kind: .swap, chainId: "eth/mainnet", sender: walletAddress(.eth).address, to: router.to.display, value: 0, data: XCTUnwrap(router.data)),
        ])

        let behindItsApprove = QuotingRelayer(estimations: estimations)
        let approved = try await preparePlan("usdteth_eth", selling: Self.usdtEthereum, buying: Self.eth, engines: [evmEngine(behindItsApprove)])

        XCTAssertEqual(approved.feeOptions.map(\.method), [.native])
        XCTAssertTrue(approved.requiresApproval)
        let unquoted = await behindItsApprove.quoted
        XCTAssertEqual(unquoted, [])
    }

    /// The battery picked for a router call relays that call at the price confirmed, asked about before
    /// the passcode as on `/v2` and held to the amount the user agreed to sell through the router, and the
    /// swap is reported pending under the relayer's hash.
    func test_aBatteryPickedForARouterCallRelaysItOnceTheUserAgrees() async throws {
        let evm = RelayEngineSpy(chain: .eth, offering: [Self.battery])
        let check = WarningCheck()
        checks = [check]
        let user = ConsentingUser(answering: true)

        let result = try await execute(
            "usdteth_eth",
            answering: Self.routerCall(),
            selling: Self.usdtEthereum,
            buying: Self.eth,
            feeMethod: .battery,
            spendLimit: 20_200_000,
            consent: user.attempt(),
            engines: [evm]
        )

        guard case let .evm(relay)? = evm.prepared.first?.context.payload else {
            return XCTFail("expected the router call to be relayed, got \(evm.prepared.map { $0.context.payload })")
        }
        XCTAssertEqual(relay.call.to.lowercased(), Self.swapsXyzRouter)
        XCTAssertEqual(evm.prepared.map { $0.confirmed }, [.batteryCharges(3)])
        XCTAssertEqual(evm.prepared.map { $0.context.payloadId }, [Self.routerCallPayload])
        XCTAssertEqual(evm.relayed, [Self.routerCallPayload])
        let asked = await user.asked
        XCTAssertEqual(asked.count, 1)
        let reads = await check.reads.all
        let router = try XCTUnwrap(reads.first?.intent.recipient)
        XCTAssertEqual(router.lowercased(), Self.swapsXyzRouter)
        XCTAssertEqual(reads.map(\.intent), [.send(20_200_000, of: Self.usdtEthereum, to: router)])
        XCTAssertEqual(reads.map(\.assetId), [Self.usdtEthereum.assetId])
        XCTAssertEqual(result.txHash, "relayed-\(Self.routerCallPayload)")
        XCTAssertEqual(
            result.broadcastedPayloads,
            [MultichainSwapBroadcastedPayload(payloadId: Self.routerCallPayload, kind: "main", payloadType: "main", txHash: "relayed-\(Self.routerCallPayload)")]
        )
        let reported = await pending.reported
        XCTAssertEqual(reported.map(\.txHash), ["relayed-\(Self.routerCallPayload)"])
        guard case let .swap(details) = try XCTUnwrap(reported.first).activityType else {
            return XCTFail("expected a pending swap")
        }
        XCTAssertEqual(details.quote?.routeId, "9462c7d9-637c-460e-8a36-a883c00b6f40")
    }

    /// The battery picked for an EVM token's deposit relays its transfer held, as on `/v2`, to the address
    /// the transfer pays: the route names neither a deposit address nor a contract it runs through.
    func test_aBatteryPickedForAnEVMTokenDepositIsHeldToTheAddressItsTransferPays() async throws {
        let evm = RelayEngineSpy(chain: .eth, offering: [Self.battery])
        let check = WarningCheck()
        checks = [check]

        try await execute(
            "usdteth_eth",
            answering: Self.evmTokenDeposit(),
            selling: Self.usdtEthereum,
            buying: Self.eth,
            feeMethod: .battery,
            spendLimit: 20_000_000,
            engines: [evm]
        )

        XCTAssertEqual(evm.relayed, [Self.evmDeposit])
        let reads = await check.reads.all
        XCTAssertEqual(reads.map(\.intent), [.send(20_000_000, of: Self.usdtEthereum, to: Self.evmDepositRecipient)])
    }

    /// A jetton deposit is relayed by the battery as the transfer of its jetton to the deposit address,
    /// and a TON battery relay is only logged, as on `/v2`: nobody is asked.
    func test_aBatteryRelaysAJettonDepositAsTheTransferOfItsJettonWithoutAsking() async throws {
        let ton = RelayEngineSpy(chain: .ton, offering: [Self.battery])
        checks = [WarningCheck()]
        let user = ConsentingUser(answering: false)
        let log = RecordedLog()
        defer { log.stop() }

        let result = try await execute(
            "ton_usdt",
            answering: SwapFixture.prepare("ton_usdt", meta: Self.jettonDeposit),
            selling: Self.usdtTon,
            buying: Self.ton,
            feeMethod: .battery,
            spendLimit: 1_000_000,
            consent: user.attempt(),
            engines: [ton]
        )
        let logged = try await log.records("Operation review found what would ask in a flow it only logs", count: 1)

        XCTAssertEqual(ton.priced.map(\.payload), [.tonJettonDeposit(TonJettonSwapDeposit(recipient: Self.omnistonRouter, amount: 1_000_000))])
        XCTAssertEqual(ton.prepared.map { $0.context.payload }, ton.priced.map(\.payload))
        let asked = await user.asked
        XCTAssertEqual(asked, [])
        XCTAssertEqual(logged.count, 1)
        XCTAssertEqual(result.txHash, "relayed-\(Self.tonUsdtMessage)")
    }

    /// A jetton sold through a router is relayed by the battery as its message, held to no contract as on
    /// `/v2`: the transfer the wallet's own wallet of the jetton makes names the router itself.
    func test_aBatteryRelaysAJettonSoldThroughARouterHeldToNoContract() async throws {
        let ton = RelayEngineSpy(chain: .ton, offering: [Self.battery])
        let check = WarningCheck()
        checks = [check]
        let log = RecordedLog()
        defer { log.stop() }

        try await execute(
            "ton_usdt",
            answering: jettonSale(),
            selling: Self.usdtTon,
            buying: Self.ton,
            feeMethod: .battery,
            spendLimit: 1_000_000,
            engines: [ton]
        )
        _ = try await log.records("Operation review found what would ask in a flow it only logs", count: 1)

        XCTAssertEqual(ton.relayed, [Self.tonUsdtMessage])
        let reads = await check.reads.all
        XCTAssertEqual(reads.map(\.intent), [.send(1_000_000, of: Self.usdtTon, to: nil)])
    }

    /// As on `/v2`, a fee in a token is only logged, and GRAM paying for a TRON transfer is asked about
    /// before the passcode.
    func test_aRelayedSwapIsAskedAboutAsOnV2() async throws {
        let token = MultichainSwapFeeOption(cost: .token(Self.usdtEthereum, amount: 115_304, isInsufficient: false))
        let trxDeposit = try SwapFixture.prepare("usdttron_ton", meta: { $0 = ["to": Self.tronDepositRecipient, "value": "20000000"] })
        let cases: [(swap: String, prepared: Data, selling: MultichainAssetDetails, buying: MultichainAssetDetails, chain: MultichainChain, option: MultichainSwapFeeOption, asks: Bool)] = try [
            ("usdteth_eth", Self.routerCall(), Self.usdtEthereum, Self.eth, .eth, token, false),
            ("usdttron_ton", trxDeposit, Self.trx, Self.ton, .tron, Self.gram, true),
        ]
        for swap in cases {
            checks = [WarningCheck()]
            let engine = RelayEngineSpy(chain: swap.chain, offering: [swap.option])
            let user = ConsentingUser(answering: true)
            let log = RecordedLog()
            defer { log.stop() }

            _ = try await execute(
                swap.swap,
                answering: swap.prepared,
                selling: swap.selling,
                buying: swap.buying,
                feeMethod: swap.option.method,
                spendLimit: 20_000_000,
                consent: user.attempt(),
                engines: [engine]
            )
            let asked = await user.asked
            XCTAssertEqual(asked.count, swap.asks ? 1 : 0, swap.option.logValue)
            XCTAssertEqual(engine.relayed.count, 1, swap.option.logValue)
            if !swap.asks {
                let logged = try await log.records("Operation review found what would ask in a flow it only logs", count: 1)
                XCTAssertEqual(logged.count, 1, swap.option.logValue)
            }
        }
    }

    /// A wallet without the coin for the fee keeps its route where a relayed method pays it, as on `/v2`,
    /// even where the coin's own fee could not be priced: the coin stays listed, short.
    func test_aWalletShortOfTheCoinGetsAPlanItsBatteryPays() async throws {
        let shortOfTheCoin = [
            ("short of the fee", RecordedSwapOperationSteps(coinCovers: false)),
            ("priced at the default fee", RecordedSwapOperationSteps(price: Self.refusedPrice, coinCovers: false)),
        ]
        for (shortage, steps) in shortOfTheCoin {
            let evm = RelayEngineSpy(chain: .eth, offering: [Self.battery])

            let plan = try await preparePlan("usdteth_eth", answering: Self.routerCall(), selling: Self.usdtEthereum, buying: Self.eth, steps: steps, engines: [evm])

            XCTAssertEqual(plan.feeOptions.map(\.method), [.battery, .native], shortage)
            XCTAssertEqual(plan.feeOptions.map(\.isInsufficient), [false, true], shortage)
            XCTAssertEqual(MultichainSwapFeeSelection.resolve(options: plan.feeOptions, picked: nil)?.method, .battery, shortage)
        }
    }

    /// A relayed method short of what it pays with keeps the route as well: the picker is where it is
    /// refilled. With no relayed method offered, the shortage stands.
    func test_aCoinShortageStandsOnlyWhereNoRelayedMethodIsOffered() async throws {
        let refillable = RelayEngineSpy(chain: .eth, offering: [MultichainSwapFeeOption(cost: .batteryCharges(count: 3, excess: nil, isInsufficient: true))])

        let plan = try await preparePlan(
            "usdteth_eth",
            answering: Self.routerCall(),
            selling: Self.usdtEthereum,
            buying: Self.eth,
            steps: RecordedSwapOperationSteps(coinCovers: false),
            engines: [refillable]
        )

        XCTAssertEqual(plan.feeOptions.map(\.method), [.battery, .native])
        XCTAssertTrue(plan.feeOptions.allSatisfy(\.isInsufficient))

        let failure = try await preparationFailure(
            of: "usdteth_eth",
            answering: Self.routerCall(),
            selling: Self.usdtEthereum,
            steps: RecordedSwapOperationSteps(coinCovers: false),
            engines: [RelayEngineSpy(chain: .eth, offering: [])]
        )

        guard case .insufficientNativeFee = failure else {
            return XCTFail("expected the coin to fall short, got \(String(describing: failure))")
        }
    }

    /// The shortage of a route a relayed method keeps is the plan's, whole: the fee and the coin the
    /// payloads send beside the amount sold, here the TON a jetton's transfer carries, so a deposit of the
    /// coin clears it in one go.
    func test_theCoinsShortageStaysOnThePlanARelayedMethodKeeps() async throws {
        let ton = RelayEngineSpy(chain: .ton, offering: [MultichainSwapFeeOption(cost: .batteryCharges(count: 3, excess: nil, isInsufficient: true))])
        let jettonDeposit = try SwapFixture.prepare("ton_usdt", meta: Self.jettonDeposit)

        let short = try await preparePlan(
            "ton_usdt",
            answering: jettonDeposit,
            selling: Self.usdtTon,
            buying: Self.ton,
            steps: RecordedSwapOperationSteps(coinCovers: false),
            engines: [ton]
        )
        let covered = try await preparePlan("ton_usdt", answering: jettonDeposit, selling: Self.usdtTon, buying: Self.ton, engines: [ton])

        XCTAssertEqual(short.feeOptions.map(\.method), [.battery, .native])
        XCTAssertEqual(short.nativeFeeShortage?.asset.assetId, Self.ton.assetId)
        XCTAssertEqual(short.nativeFeeShortage?.requiredAmount, 80_021_001)
        XCTAssertNil(covered.nativeFeeShortage)
    }

    /// A route that expired before the swap was confirmed is neither prepared by the relayer nor reviewed.
    func test_aRelayedRouteThatExpiredIsNeitherPreparedNorReviewed() async throws {
        let evm = RelayEngineSpy(chain: .eth, offering: [Self.battery])
        let check = WarningCheck()
        checks = [check]
        let service = try makeService(backend: SwapBackend(answering: Self.routerCall()), engines: [evm])
        let plan = try await service.prepareExecutionPlan(
            swapWallet: swapWallet(),
            sourceAsset: asset(Self.usdtEthereum),
            destinationAsset: asset(Self.eth),
            route: quotedRoute("usdteth_eth")
        )
        clock.advance(by: 42)

        do {
            _ = try await service.execute(
                signer: .mnemonic(passcodeProvider: { "passcode" }),
                swapWallet: swapWallet(),
                sourceAsset: asset(Self.usdtEthereum),
                destinationAsset: asset(Self.eth),
                executionPlan: plan,
                feeMethod: .battery,
                spendLimit: 20_000_000,
                consent: ConsentingUser(answering: true).attempt()
            )
            XCTFail("expected the expired route to stop the swap")
        } catch {
            XCTAssertEqual(error as? MultichainSwapExecutionFailure, .routeExpired(routeId: "9462c7d9-637c-460e-8a36-a883c00b6f40"))
        }

        XCTAssertTrue(evm.prepared.isEmpty)
        let reads = await check.reads.all
        XCTAssertEqual(reads, [])
    }

    /// The operation's deadline holds a relayed swap as the route's holds one on `/v2`: one the user read
    /// past is not relayed, and fails as an expired payload, which a fresh quote recovers from.
    func test_aRelayedRouteTheUserReadsPastItsDeadlineIsNotRelayed() async throws {
        let clock = clock
        let evm = RelayEngineSpy(chain: .eth, offering: [Self.battery])
        checks = [WarningCheck()]

        do {
            try await execute(
                "usdteth_eth",
                answering: Self.routerCall(),
                selling: Self.usdtEthereum,
                buying: Self.eth,
                feeMethod: .battery,
                spendLimit: 20_000_000,
                consent: ConsentingUser(answering: true) { clock.advance(by: 42) }.attempt(),
                engines: [evm]
            )
            XCTFail("expected the lapsed route to stop the swap")
        } catch {
            XCTAssertEqual(error as? MultichainSwapExecutionFailure, .payloadExpired(payloadId: Self.routerCallPayload))
        }

        XCTAssertEqual(evm.prepared.count, 1)
        XCTAssertEqual(evm.relayed, [])
        let reported = await pending.reported
        XCTAssertEqual(reported, [])
    }

    /// The operation was live a moment before the relayer prepared it, so a deadline passed meanwhile is the
    /// route's, not a clock running ahead: the swap is neither put to the user nor relayed.
    func test_aRelayedRouteThatExpiredWhileItWasPreparedIsNeitherReviewedNorRelayed() async throws {
        let clock = clock
        let evm = RelayEngineSpy(chain: .eth, offering: [Self.battery]) { clock.advance(by: 42) }
        let check = WarningCheck()
        checks = [check]
        let user = ConsentingUser(answering: true)

        do {
            try await execute(
                "usdteth_eth",
                answering: Self.routerCall(),
                selling: Self.usdtEthereum,
                buying: Self.eth,
                feeMethod: .battery,
                spendLimit: 20_000_000,
                consent: user.attempt(),
                engines: [evm]
            )
            XCTFail("expected the lapsed route to stop the swap")
        } catch {
            XCTAssertEqual(error as? MultichainSwapExecutionFailure, .payloadExpired(payloadId: Self.routerCallPayload))
        }

        let reads = await check.reads.all
        XCTAssertEqual(reads, [])
        let asked = await user.asked
        XCTAssertEqual(asked, [])
        XCTAssertEqual(evm.relayed, [])
        let reported = await pending.reported
        XCTAssertEqual(reported, [])
    }

    /// The engine asks for the passcode as it sends, and the passcode can outlast the route: one entered
    /// past the deadline unlocks nothing, and the swap fails as the expired route a fresh quote replaces.
    func test_aRelayedRouteThatExpiredBehindThePasscodeIsNotRelayed() async throws {
        let clock = clock
        let evm = RelayEngineSpy(chain: .eth, offering: [Self.battery])

        do {
            try await execute(
                "usdteth_eth",
                answering: Self.routerCall(),
                selling: Self.usdtEthereum,
                buying: Self.eth,
                feeMethod: .battery,
                spendLimit: 20_000_000,
                passcode: {
                    clock.advance(by: 42)
                    return "passcode"
                },
                engines: [evm]
            )
            XCTFail("expected the expired route to stop the swap")
        } catch {
            XCTAssertEqual(error as? MultichainSwapExecutionFailure, .routeExpired(routeId: "9462c7d9-637c-460e-8a36-a883c00b6f40"))
        }

        XCTAssertEqual(evm.prepared.count, 1)
        XCTAssertEqual(evm.relayed, [])
        let reported = await pending.reported
        XCTAssertEqual(reported, [])
    }

    /// A passcode the user withholds is their cancel, however late they withhold it.
    func test_aPasscodeWithheldPastTheDeadlineIsTheUsersCancel() async throws {
        let clock = clock
        let evm = RelayEngineSpy(chain: .eth, offering: [Self.battery])

        do {
            try await execute(
                "usdteth_eth",
                answering: Self.routerCall(),
                selling: Self.usdtEthereum,
                buying: Self.eth,
                feeMethod: .battery,
                spendLimit: 20_000_000,
                passcode: {
                    clock.advance(by: 42)
                    return nil
                },
                engines: [evm]
            )
            XCTFail("expected the withheld passcode to stop the swap")
        } catch {
            XCTAssertEqual(error as? MultichainSwapExecutionFailure, .canceled)
        }

        XCTAssertEqual(evm.relayed, [])
    }

    /// A route prepared on `/v3` is a wallet's own mnemonic's to sign, whatever pays its fee.
    func test_aHardwareWalletRelaysNothingOfARoutePreparedOnV3() async throws {
        let evm = RelayEngineSpy(chain: .eth, offering: [Self.battery])
        let plan = try await preparePlan("usdteth_eth", answering: Self.routerCall(), selling: Self.usdtEthereum, buying: Self.eth, engines: [evm])

        do {
            _ = try await makeService(backend: SwapBackend(), engines: [evm]).execute(
                signer: .device(Self.device),
                swapWallet: swapWallet(keys: .device),
                sourceAsset: asset(Self.usdtEthereum),
                destinationAsset: asset(Self.eth),
                executionPlan: plan,
                feeMethod: .battery,
                spendLimit: 20_000_000,
                consent: ConsentingUser(answering: true).attempt()
            )
            XCTFail("expected a hardware wallet to be refused")
        } catch {
            guard case .internal = error as? MultichainSwapExecutionFailure else {
                return XCTFail("expected an internal failure, got \(error)")
            }
        }
        XCTAssertTrue(evm.prepared.isEmpty)
    }

    // MARK: - TRC-20 deposits

    /// A TRC-20 deposit's calldata is read into the transfer the TRON relayer takes for a `/v2` deposit:
    /// what it offers there, the battery and GRAM, it offers here beside the chain's coin.
    func test_aTRC20DepositIsOfferedWhatTheTronRelayerOffersForItsTransfer() async throws {
        let tron = RelayEngineSpy(chain: .tron, offering: [Self.battery, Self.gram])

        let plan = try await preparePlan("usdttron_ton", selling: Self.usdtTron, buying: Self.ton, engines: [tron])

        XCTAssertEqual(plan.feeOptions.map(\.method), [.battery, .gram, .native])
        XCTAssertEqual(tron.priced.map(\.payload), [.tron(TronSwapTransfer(to: Self.tronDepositRecipient, amount: 20_000_000))])
        XCTAssertEqual(tron.priced.map(\.payloadId), [Self.tronDeposit])
        XCTAssertEqual(tron.priced.map(\.requiresApproval), [false])
        XCTAssertEqual(tron.priced.map(\.spentSourceAmount), [20_000_000])
    }

    /// Calldata that is anything but the plain transfer of the token sold leaves the relayer nothing to
    /// price: the swap is paid in the chain's coin.
    func test_aTRONCallOtherThanATransferOfTheTokenSoldIsPaidInTheCoin() async throws {
        let edits: [(String, (inout [String: Any]) -> Void)] = [
            ("three words", { $0["data"] = ($0["data"] as? String ?? "") + String(repeating: "0", count: 64) }),
            ("an approve", { $0["data"] = "095ea7b3" + (($0["data"] as? String)?.dropFirst(8) ?? "") }),
            ("TRX sent along", { $0["value"] = "1" }),
            ("another contract", { $0["to"] = "TCaxmZvD5kysgFNSqovSpxKKkZdD818cvr" }),
        ]
        for (edit, meta) in edits {
            let tron = RelayEngineSpy(chain: .tron, offering: [Self.battery])

            let plan = try await preparePlan("usdttron_ton", answering: SwapFixture.prepare("usdttron_ton", meta: meta), selling: Self.usdtTron, buying: Self.ton, engines: [tron])

            XCTAssertEqual(plan.feeOptions.map(\.method), [.native], edit)
            XCTAssertTrue(tron.priced.isEmpty, edit)
        }
    }

    /// The battery picked for a TRC-20 deposit relays the deposit's transfer at the price confirmed, asked
    /// about before the passcode and held, as on `/v2`, to the amount the user agreed to sell and to the
    /// address the transfer pays, and the swap is reported pending under the relayer's hash.
    func test_aBatteryPickedForATRC20DepositRelaysItsTransferOnceTheUserAgrees() async throws {
        let tron = RelayEngineSpy(chain: .tron, offering: [Self.battery])
        let check = WarningCheck()
        checks = [check]
        let user = ConsentingUser(answering: true)

        let result = try await execute(
            "usdttron_ton",
            selling: Self.usdtTron,
            buying: Self.ton,
            feeMethod: .battery,
            spendLimit: 20_200_000,
            consent: user.attempt(),
            engines: [tron]
        )

        XCTAssertEqual(tron.prepared.map { $0.confirmed }, [.batteryCharges(3)])
        XCTAssertEqual(tron.prepared.map { $0.context.payload }, [.tron(TronSwapTransfer(to: Self.tronDepositRecipient, amount: 20_000_000))])
        XCTAssertEqual(tron.relayed, [Self.tronDeposit])
        let asked = await user.asked
        XCTAssertEqual(asked.count, 1)
        let reads = await check.reads.all
        XCTAssertEqual(reads.map(\.intent), [.send(20_200_000, of: Self.usdtTron, to: Self.tronDepositRecipient)])
        XCTAssertEqual(result.txHash, "relayed-\(Self.tronDeposit)")
        let reported = await pending.reported
        XCTAssertEqual(reported.map(\.txHash), ["relayed-\(Self.tronDeposit)"])
    }

    /// What the relayer sends is held to what the operation names, not to what its calldata was read as:
    /// a deposit address the route names is the recipient of the review.
    func test_aRelayedDepositIsReviewedAsTheOperationNamesItsRecipient() async throws {
        let deposit = "TJRabPrwbZy45sbavfcjinPJC18kjpRTv8"
        let check = WarningCheck()
        checks = [check]

        try await execute(
            "usdttron_ton",
            answering: SwapFixture.prepare("usdttron_ton", summary: { $0["deposit_address"] = deposit }),
            selling: Self.usdtTron,
            buying: Self.ton,
            feeMethod: .battery,
            spendLimit: 20_000_000,
            engines: [RelayEngineSpy(chain: .tron, offering: [Self.battery])]
        )

        let reads = await check.reads.all
        XCTAssertEqual(reads.map(\.intent.recipient), [deposit])
    }

    func test_chainKitsFailuresAreTheOnesTheSwapShows() throws {
        let operation = try ChainKitOperationSender.parse(
            id: "route",
            payloads: #"[{"chain_id":"eth/mainnet","id":"approve","type":"main","version":1,"meta":{"to":"0xdac17f958d2ee523a2206206994597c13d831ec7","value":"0"}}]"#
        )
        let failure = { (error: any Error) in ChainKitSwapOperationSteps.failure(error, of: operation) }

        XCTAssertEqual(failure(CancellationError()), .canceled)
        XCTAssertEqual(failure(ChainKitOperationError.quoteExpired), .routeExpired(routeId: "route"))
        guard case .broadcastFailed("approve", .insufficientBalance, _) = failure(ChainKitOperationError.insufficientFunds(payloadId: "approve")) else {
            return XCTFail("expected a refusal for want of funds to read as a shortage")
        }
        guard case .nonceFailed("approve", .networkError, _) = failure(ChainKitOperationError.nonceUnavailable("offline", kind: .networkError)) else {
            return XCTFail("expected an unread nonce to keep its kind")
        }
        guard case .signingFailed("approve", .verificationFailed, _) = failure(
            ChainKitOperationError.signingFailed(payloadId: "approve", reason: "refused", kind: .verificationFailed)
        ) else {
            return XCTFail("expected the signer's kind of refusal")
        }
        guard case .broadcastFailed("approve", .noAvailableNodes, _) = failure(
            ChainKitOperationError.broadcastFailed(payloadId: "approve", sent: [], reason: "no nodes", kind: .noAvailableNodes)
        ) else {
            return XCTFail("expected a broadcast with no node to read as such")
        }
        guard case .internal = failure(ChainKitOperationError.keyMismatch(expected: "a", unlocked: "b")) else {
            return XCTFail("expected anything else to fail as no cancellation")
        }
    }

    /// chain-kit's sender signs an EVM token sale as its plan priced it: the approve at the nonce the node
    /// gives, at the gas the backend quoted, and the swap at the next nonce, at the fee given for it,
    /// with nothing priced on the way. Each is kept before it is broadcast, which leaves the node out.
    func test_anEVMTokenSaleIsSignedApproveAtTheNonceReadAndSwapAtTheNext() async throws {
        let response = try await SwapBackend(answering: SwapFixture.prepare("usdteth_eth")).api.prepareCrossSwapRouteV3(routeId: "route", walletId: "wallet-1")
        let operation = try MultichainSwapPreparedOperation(response).operation
        let (approve, swap) = (operation.payloads[0], operation.payloads[1])
        let wallet = try RecordedSwapOperationSteps.unlocked()
        let account = try ChainKitOperationSender.account(of: walletAddress(.eth), asset: nil)
        let routerFee = FeeEip1559(
            asset: account.chain.toAsset(),
            limit: BignumBigInteger(long: 900_000),
            networkPrice: BignumBigInteger(long: 301_418_031),
            maxPrice: BignumBigInteger(long: 401_418_031),
            minerPrice: BignumBigInteger(long: 1_000_000),
            amount: BignumBigInteger(long: 361_276_227_900_000)
        )
        let fees: [any Fee] = try [XCTUnwrap(approve.fee), routerFee]
        let client = CryptoKitClient(
            netModule: ModuleNetModule(netConfig: ModuleNetConfig(isLogging: false, logger: nil, userAgent: nil, sessionProvider: nil, nodeManifestHost: nil))
        )
        let sender = ChainKitOperationSender(client: client, readNonce: { _ in BignumBigInteger(long: 7) })
        var kept = [ChainKitSignedTransaction]()

        do {
            _ = try await sender.send(operation, account: account, wallet: wallet, expiresAt: .distantFuture, fees: fees) {
                kept.append($0)
                throw KeptBeforeBroadcast()
            }
            XCTFail("expected the send to stop where the approve is kept")
        } catch is KeptBeforeBroadcast {}
        var broadcast = try XCTUnwrap(kept.first)
        broadcast.acknowledged = true
        do {
            _ = try await sender.send(operation, account: account, wallet: wallet, expiresAt: .distantFuture, fees: fees, saved: [broadcast]) {
                kept.append($0)
                throw KeptBeforeBroadcast()
            }
            XCTFail("expected the send to stop where the swap is kept")
        } catch is KeptBeforeBroadcast {}

        let mediator = client.blockchain.getMediator(network: account.chain.network.type)
        func hash(of payload: Payload, at fee: any Fee, nonce: Int64) async throws -> String? {
            let signed = try await mediator.operation.sign(payload: payload, account: account, fee: fee, nonce: BignumBigInteger(long: nonce), wallet: wallet).getOrNull()
            return try mediator.operation.transactionHash(payload: XCTUnwrap(signed)).getOrNull().map { $0 as String }
        }
        XCTAssertEqual(kept.map(\.payloadId), [approve.id, swap.id])
        XCTAssertEqual(kept.map(\.nonce), ["7", "8"])
        let approveHash = try await hash(of: approve, at: fees[0], nonce: 7)
        let swapHash = try await hash(of: swap, at: routerFee, nonce: 8)
        XCTAssertNotNil(approveHash)
        XCTAssertNotNil(swapHash)
        XCTAssertEqual(kept.map(\.hash), [approveHash, swapHash])
    }

    /// The approve is signed at the gas the backend quoted for it: chain-kit asks no node for its price.
    func test_chainKitPricesAPayloadAtTheFeeTheBackendQuoted() async throws {
        let response = try await SwapBackend(answering: SwapFixture.prepare("usdteth_eth")).api.prepareCrossSwapRouteV3(routeId: "route", walletId: "wallet-1")
        let approve = try XCTUnwrap(MultichainSwapPreparedOperation(response).operation.payloads.first)
        let steps = ChainKitSwapOperationSteps(
            client: CryptoKitClient(
                netModule: ModuleNetModule(netConfig: ModuleNetConfig(isLogging: false, logger: nil, userAgent: nil, sessionProvider: nil, nodeManifestHost: nil))
            ),
            unlocker: SwapWalletUnlocker(mnemonicAccess: .inMemory(seed: "swap-operation")),
            assetDetailsProvider: { _, _ in nil }
        )

        let fee = try await steps.fee(of: approve, account: ChainKitOperationSender.account(of: walletAddress(.eth), asset: nil))

        XCTAssertTrue(fee as AnyObject === approve.fee as AnyObject)
    }
}

private extension MultichainSwapOperationExecutionTests {
    /// The recorded Ethereum route with its approve granted already: the router call alone.
    static func routerCall() throws -> Data {
        try SwapFixture.prepare("usdteth_eth", operation: { $0["payloads"] = Array(($0["payloads"] as? [[String: Any]] ?? []).suffix(1)) })
    }

    /// The recorded Ethereum route as swaps.xyz deposits the USDT sold: one payload, the token's `transfer`
    /// of the 20 USDT to an address the route does not name.
    static func evmTokenDeposit() throws -> Data {
        let transfer = try XCTUnwrap(EVMGaslessCall.erc20TransferData(recipient: evmDepositRecipient, amount: 20_000_000))
        return try SwapFixture.prepare(
            "usdteth_eth",
            operation: { $0["payloads"] = Array(($0["payloads"] as? [[String: Any]] ?? []).suffix(1)) },
            payload: { $0["id"] = evmDeposit },
            meta: { $0 = ["to": "0xdac17f958d2ee523a2206206994597c13d831ec7", "value": "0", "data": transfer] }
        )
    }

    /// The last payload of the recorded TON swap as a deposit of a jetton.
    static func jettonDeposit(_ meta: inout [String: Any]) {
        meta = ["to": omnistonRouter, "value": "1000000", "token": "0:b113a994b5024a16719f69139328eb759596c38a25f59028b146fecdc3621dfe"]
    }

    /// chain-kit refusing to price a payload, as a node refuses to emulate a message the wallet cannot pay.
    static func refusedPrice(_: Payload, _: ChainKit.Account) throws(MultichainSwapExecutionFailure) -> any Fee {
        throw .emulationFailed(kind: .unknown, reason: "refused")
    }

    /// TON's default fee of a coin message.
    static func tonDefaultFee(_: Payload, _ account: ChainKit.Account) -> any Fee {
        FeeValue(asset: account.chain.toAsset(), amount: BignumBigInteger(long: 5_500_000))
    }

    /// chain-kit binding no transaction to a payload, as it binds none to a jetton deposit from the coin's account.
    static func unboundPrice(_ payload: Payload, _: ChainKit.Account) throws(MultichainSwapExecutionFailure) -> any Fee {
        throw .invalidPayload(payloadId: payload.id, reason: "chain kit binds no transaction to the payload")
    }

    static let device = DeviceTransferSigner(
        evm: { _ in throw CancellationError() },
        tron: { _ in throw CancellationError() },
        solana: { _ in throw CancellationError() },
        bitcoin: { _ in throw CancellationError() },
        ton: { _ in throw CancellationError() },
        evmMessage: { _ in throw CancellationError() },
        evmTypedData: { _, _ in throw CancellationError() },
        tronMessage: { _ in throw CancellationError() }
    )

    func makeService(
        backend: SwapBackend,
        steps: RecordedSwapOperationSteps = RecordedSwapOperationSteps(),
        v2: V2SwapServiceSpy = V2SwapServiceSpy(),
        engines: [any MultichainSwapRelayedFeeEngine] = []
    ) -> MultichainSwapExecutionServiceImplementation {
        MultichainSwapExecutionServiceImplementation(
            swapService: v2,
            swapAPI: backend.api,
            swapPipeline: UnusedSwapPipeline(),
            operationSteps: steps,
            pendingTransactionsService: pending,
            feeMethodResolver: MultichainSwapFeeMethodResolver(engines: engines),
            gate: OperationGate { [checks] in checks },
            now: { [clock] in clock.now }
        )
    }

    /// The EVM relayer's engine on Ethereum, which the relayer serves, switched on, charges to spare.
    func evmEngine(_ relayer: QuotingRelayer) -> MultichainSwapEVMRelayedFeeEngine {
        MultichainSwapEVMRelayedFeeEngine(
            chain: .eth,
            relayer: relayer,
            signer: UnusedRelayedOperationSigner(),
            relayedChains: { [.eth] },
            isRelayerEnabled: { _ in true },
            batteryCharges: { _ in .available(100) },
            walletTokens: { _, _ in [:] }
        )
    }

    /// The plan of the route quoted for the recorded `swap`, prepared as `prepared` answers, else as recorded.
    func preparePlan(
        _ swap: String,
        answering prepared: Data? = nil,
        selling source: MultichainAssetDetails,
        buying destination: MultichainAssetDetails,
        steps: RecordedSwapOperationSteps = RecordedSwapOperationSteps(),
        engines: [any MultichainSwapRelayedFeeEngine]
    ) async throws -> MultichainSwapExecutionPlan {
        try await makeService(backend: SwapBackend(answering: prepared ?? SwapFixture.prepare(swap)), steps: steps, engines: engines).prepareExecutionPlan(
            swapWallet: swapWallet(),
            sourceAsset: asset(source),
            destinationAsset: asset(destination),
            route: quotedRoute(swap)
        )
    }

    /// The route the recorded quote of `swap` offers, as the swap screen picks it.
    func quotedRoute(_ swap: String) async throws -> MultichainSwapRoute {
        let quote = try await SwapBackend(answering: SwapFixture.data("confirm_v3_quote_\(swap)")).api.createCrossSwapQuoteV3(
            request: MultichainSwapQuoteRequest(sourceAsset: "", destinationAsset: "", amount: .source(1), senderAddress: "", recipientAddress: ""),
            walletId: "wallet-1"
        )
        return try XCTUnwrap(quote.preferredRoute(at: clock.now))
    }

    /// The recorded swap `swap`, prepared as `answering` says, else as recorded, then reviewed and sent,
    /// its fee paid with `feeMethod`, unlocked by what `passcode` answers.
    @discardableResult
    func execute(
        _ swap: String,
        answering prepared: Data? = nil,
        selling source: MultichainAssetDetails,
        buying destination: MultichainAssetDetails,
        feeMethod: MultichainSwapFeeMethod = .native,
        spendLimit: BigUInt = 1_000_000_000,
        consent: OperationConsent = ConsentingUser(answering: true).attempt(),
        passcode: @escaping () async -> String? = { "passcode" },
        steps: RecordedSwapOperationSteps = RecordedSwapOperationSteps(),
        engines: [any MultichainSwapRelayedFeeEngine] = []
    ) async throws -> MultichainSwapExecutionResult {
        let service = try makeService(backend: SwapBackend(answering: prepared ?? SwapFixture.prepare(swap)), steps: steps, engines: engines)
        let wallet = try swapWallet()
        let plan = try await service.prepareExecutionPlan(
            swapWallet: wallet,
            sourceAsset: asset(source),
            destinationAsset: asset(destination),
            route: quotedRoute(swap)
        )
        return try await service.execute(
            signer: .mnemonic(passcodeProvider: passcode),
            swapWallet: wallet,
            sourceAsset: asset(source),
            destinationAsset: asset(destination),
            executionPlan: plan,
            feeMethod: feeMethod,
            spendLimit: spendLimit,
            consent: consent
        )
    }

    /// Why the route quoted for the recorded `swap`, sold from `source` and prepared as `prepared` answers,
    /// else as recorded, is not planned.
    func preparationFailure(
        of swap: String = "ton_usdt",
        answering prepared: Data? = nil,
        selling source: MultichainAssetDetails = MultichainSwapOperationExecutionTests.ton,
        steps: RecordedSwapOperationSteps = RecordedSwapOperationSteps(),
        engines: [any MultichainSwapRelayedFeeEngine] = []
    ) async -> MultichainSwapExecutionFailure? {
        do {
            _ = try await makeService(backend: SwapBackend(answering: prepared ?? SwapFixture.prepare(swap)), steps: steps, engines: engines).prepareExecutionPlan(
                swapWallet: swapWallet(),
                sourceAsset: asset(source),
                destinationAsset: asset(Self.eth),
                route: quotedRoute(swap)
            )
            return nil
        } catch {
            return error as? MultichainSwapExecutionFailure
        }
    }

    func preparationFailure(backend: SwapBackend) async -> MultichainSwapExecutionFailure? {
        do {
            _ = try await makeService(backend: backend).prepareExecutionPlan(
                swapWallet: swapWallet(),
                sourceAsset: asset(Self.ton),
                destinationAsset: asset(Self.usdtTon),
                route: quotedRoute("ton_usdt")
            )
            return nil
        } catch {
            return error as? MultichainSwapExecutionFailure
        }
    }

    func operation(of plan: MultichainSwapExecutionPlan) throws -> MultichainSwapOperation {
        guard case let .operation(operation) = plan.signs else {
            throw NotAnOperation()
        }
        return operation
    }

    func asset(_ details: MultichainAssetDetails) -> MultichainAsset {
        MultichainAsset(asset: details, price: MultichainAssetPrice(prices: [:], diff24h: [:], diff7d: [:]), balance: 0)
    }

    /// The wallet's address on `chain` as the test mnemonic derives it, with the key it stores.
    func walletAddress(_ chain: MultichainChain, type: ChainKit.Address.Type_ = .default_, as addressType: MultichainWalletAddressType? = nil) throws -> MultichainWalletAddress {
        let unlocked = try RecordedSwapOperationSteps.unlocked()
        let key = unlocked.getPublicKey(chain: chain.asChainKitChain)
        return MultichainWalletAddress(
            chain: chain,
            address: unlocked.getAddress(chain: chain.asChainKitChain, type: type).display,
            type: addressType,
            publicKey: MultichainPublicKey(defaultHex: key.defaultHex, segWit: key.segWit)
        )
    }

    func ethAddress() throws -> String {
        try walletAddress(.eth).address.lowercased()
    }

    func tonAddress() throws -> String {
        try walletAddress(.ton, type: .tonv4r2, as: .tonV4R2).address.lowercased()
    }

    /// The recorded TON swap as a sale of 1 USDT through Omniston's router, as `/v3` prepares one: a
    /// message to the wallet's own USDT wallet, its body the jetton's transfer to the router.
    func jettonSale() throws -> Data {
        let transfer = try jettonTransfer(to: Self.omnistonRouter)
        return try SwapFixture.prepare("ton_usdt", meta: { $0 = ["to": Self.usdtTonWallet, "value": "300000000", "body": transfer] })
    }

    /// The body of the transfer of 1 USDT to `destination` the wallet's own USDT wallet makes, the excess
    /// back to the wallet.
    func jettonTransfer(to destination: String) throws -> String {
        let transfer = try JettonTransferData(
            queryId: 0,
            amount: 1_000_000,
            toAddress: TonSwift.Address.parse(destination),
            responseAddress: TonSwift.Address.parse(walletAddress(.ton, type: .tonv4r2, as: .tonV4R2).address),
            forwardAmount: 250_000_000,
            forwardPayload: nil
        )
        return try Builder().store(transfer).endCell().toBoc().base64EncodedString()
    }

    func swapWallet(
        keys: MultichainSwapWallet.Keys = .hd,
        registration: MultichainSwapWallet.Registration = .registered(walletId: "wallet-1"),
        kind: KeeperCore.WalletKind = .Regular(PublicKey(data: Data(repeating: 1, count: 32)), .v4R2)
    ) throws -> MultichainSwapWallet {
        let addresses = try [
            walletAddress(.eth),
            walletAddress(.ton, type: .tonv4r2, as: .tonV4R2),
            walletAddress(.tron),
            walletAddress(.sol),
        ]
        let wallet = Wallet(
            id: "wallet",
            identity: WalletIdentity(network: .mainnet, kind: kind),
            metaData: WalletMetaData(label: "Test wallet", tintColor: .defaultColor, icon: .icon(.wallet)),
            setupSettings: WalletSetupSettings(isSetupFinished: true),
            batterySettings: BatterySettings(),
            multichain: .multichain(MultichainWalletState(walletId: "wallet-1", addresses: addresses))
        )
        return MultichainSwapWallet(wallet: wallet, addresses: addresses, registration: registration, keys: keys)
    }
}

private struct NotAnOperation: Error {}

private struct KeptBeforeBroadcast: Error {}

/// A relayed fee method on `chain`: offers what it is given for whatever it is asked to price, runs
/// `onPrepare` as it prepares, and relays what it prepared under the hash `relayed-<payload id>` once the
/// signer's passcode unlocks it; keeps what it was asked, in order.
private final class RelayEngineSpy: MultichainSwapRelayedFeeEngine {
    let chain: MultichainChain
    private let offered: [MultichainSwapFeeOption]
    private let onPrepare: () -> Void
    private(set) var priced = [MultichainSwapFeeContext]()
    private(set) var prepared = [(context: MultichainSwapFeeContext, confirmed: MultichainSwapRelayedFee)]()
    private(set) var relayed = [String]()

    init(chain: MultichainChain, offering offered: [MultichainSwapFeeOption], onPrepare: @escaping () -> Void = {}) {
        self.chain = chain
        self.offered = offered
        self.onPrepare = onPrepare
    }

    func options(context: MultichainSwapFeeContext) async -> [MultichainSwapFeeOption] {
        priced.append(context)
        return offered
    }

    func prepare(
        context: MultichainSwapFeeContext,
        confirmed: MultichainSwapRelayedFee
    ) async throws(MultichainSwapExecutionFailure) -> MultichainSwapPreparedRelay {
        onPrepare()
        prepared.append((context, confirmed))
        return MultichainSwapPreparedRelay(
            signables: { [chain] intent in
                // What a relayer signs, as the review reads it: here a payment to the wallet's own address.
                let address = try XCTUnwrap(context.swapWallet.address(for: chain))
                return try [SignableOperation(
                    operation: ChainKitOperationSender.parse(
                        id: "relayed",
                        payloads: #"[{"chain_id":"\#(chain.relayerChainId)","id":"relayed","type":"main","version":1,"meta":{"to":"\#(address)","value":"0"}}]"#
                    ),
                    account: context.sourceAccount(on: chain),
                    intent: intent,
                    fidelity: .exact
                )]
            },
            expiresAt: nil,
            send: { signer throws(MultichainSwapExecutionFailure) in
                // As the engines unlock the wallet: without a passcode nothing is signed.
                guard case let .mnemonic(passcodeProvider) = signer, await passcodeProvider() != nil else {
                    throw .canceled
                }
                self.relayed.append(context.payloadId)
                return "relayed-\(context.payloadId)"
            }
        )
    }
}

/// The EVM relayer quoting every call at `estimations`, keeping the calls it was asked to price.
private actor QuotingRelayer: EVMGaslessRelaying {
    private let estimations: [EVMGaslessEstimation]
    private(set) var quoted = [EVMGaslessCall]()

    init(estimations: [EVMGaslessEstimation]) {
        self.estimations = estimations
    }

    func estimate(wallet _: Wallet, call: EVMGaslessCall) async throws -> [EVMGaslessEstimation] {
        quoted.append(call)
        return estimations
    }

    func emulate(wallet _: Wallet, calls _: [EVMGaslessCall], assetId _: String) async throws -> EVMGaslessEmulation {
        throw SwapBackendError.unanswered("/gasless/emulate")
    }

    func emulate(wallet _: Wallet, batch _: EVMBatchRelay, assetId _: String) async throws -> EVMGaslessEmulation {
        throw SwapBackendError.unanswered("/gasless/emulate")
    }

    func send(wallet _: Wallet, signedOperation _: Data) async throws -> String? {
        throw SwapBackendError.unanswered("/gasless/send")
    }
}

/// A signer no option of a plan reaches.
private struct UnusedRelayedOperationSigner: MultichainRelayedOperationSigner {
    func signRelayedOperation(
        passcodeProvider _: @escaping () async -> String?,
        wallet _: Wallet,
        chain _: MultichainChain,
        operation _: MultichainRelayedOperation
    ) async throws(MultichainTransactionFailure) -> Data {
        throw .canceled
    }
}

/// chain-kit answering `error` about what it reads, rated as the check rates that answer.
private struct Verdict: OperationCheck {
    let error: @Sendable (SignableOperation) -> ValidationError

    func findings(of signable: SignableOperation) throws -> [OperationFinding] {
        try ChainKitValidationCheck.findings([error(signable)], of: signable, intent: ChainKitValidationCheck.intent(of: signable))
    }
}

/// `/v2/crosschain` as a route it should never prepare reaches it: counted, and refused.
private final class V2SwapServiceSpy: MultichainSwapService {
    private(set) var prepareCount = 0

    func listCrossSwapAssets(query _: MultichainSwapAssetsQuery) async throws -> [MultichainSwapAsset] {
        []
    }

    func getCrossSwapConfig(walletId _: String, fromAssetId _: String?, toAssetId _: String?) async throws -> MultichainSwapConfig {
        throw SwapBackendError.unanswered("config")
    }

    func createCrossSwapQuote(request _: MultichainSwapQuoteRequest, walletId _: String?) async throws(MultichainSwapAPIError) -> MultichainSwapQuote {
        throw .unknown(statusCode: -1)
    }

    func createCrossSwapQuoteV3(request _: MultichainSwapQuoteRequest, walletId _: String) async throws(MultichainSwapAPIError) -> MultichainSwapQuote {
        throw .unknown(statusCode: -1)
    }

    func prepareCrossSwapRoute(routeId _: String, request _: MultichainSwapPrepareRouteRequest?, walletId _: String?) async throws -> MultichainSwapPrepare {
        prepareCount += 1
        throw SwapBackendError.unanswered("/v2/crosschain/routes/prepare")
    }
}

/// The `/v2` pipeline, which no route `/v3` prepared reaches.
private struct UnusedSwapPipeline: ChainKitSwapPipeline {
    func prepareSwapPayloads(
        swapWallet _: MultichainSwapWallet,
        sourceAsset _: MultichainAsset,
        destinationAsset _: MultichainAsset,
        payloads _: MultichainSwapRoutePayloads,
        provider _: MultichainSwapProvider
    ) async throws(MultichainSwapExecutionFailure) -> MultichainSwapPipelinePreparation {
        throw .internal(reason: "the /v2 pipeline prepared a route")
    }

    func executeSwapPayloads(
        signer _: MultichainTransferSigner,
        swapWallet _: MultichainSwapWallet,
        sourceAsset _: MultichainAsset,
        destinationAsset _: MultichainAsset,
        payloads _: MultichainSwapRoutePayloads,
        payloadFees _: MultichainSwapPayloadFees,
        provider _: MultichainSwapProvider
    ) async throws(MultichainSwapExecutionFailure) -> MultichainSwapBroadcastResult {
        throw .internal(reason: "the /v2 pipeline sent a route")
    }
}
