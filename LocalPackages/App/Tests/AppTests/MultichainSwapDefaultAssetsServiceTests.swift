@testable import App
import BigInt
import Foundation
@testable import KeeperCore
import XCTest

final class MultichainSwapDefaultAssetsServiceTests: XCTestCase {
    func test_loadUsesServerDefaultPair() async throws {
        let walletAsset = asset(
            assetId: "base/mainnet/coin",
            symbol: "BASE",
            decimals: 18,
            balance: 42
        )
        let config = makeConfig(
            sourceAssetId: "base/mainnet/coin",
            destinationAssetId: "eth/mainnet/coin",
            chains: [
                "base": .init(optionsBps: [50, 100], defaultBps: 100),
            ]
        )
        let multichainService = DefaultAssetsMultichainServiceSpy(
            walletAssetsResult: .success(.init(assets: [walletAsset], nextCursor: nil, fiatPrice: [:]))
        )
        let swapService = DefaultAssetsSwapServiceSpy(
            catalogResult: .success([
                swapAsset(assetId: "eth/mainnet/coin", symbol: "ETH", decimals: 18, chainId: "eth/mainnet"),
                swapAsset(assetId: "base/mainnet/coin", symbol: "BASE", decimals: 18, chainId: "base/mainnet"),
            ]),
            configResult: .success(config)
        )

        let result = try await makeService(
            multichainService: multichainService,
            swapService: swapService
        ).load()

        XCTAssertEqual(result.sendAsset, walletAsset)
        XCTAssertEqual(result.receiveAsset.asset.assetId, "eth/mainnet/coin")
        XCTAssertEqual(result.receiveAsset.balance, .zero)
        XCTAssertEqual(result.catalog.count, 2)
        XCTAssertEqual(result.slippage, config.slippage)

        let requests = await multichainService.walletAssetsRequests()
        XCTAssertEqual(requests.map(\.walletId), ["wallet"])
        XCTAssertEqual(requests.map(\.currencies), [["usd"]])
        XCTAssertEqual(requests.map(\.showHidden), [false])
        let configRequests = await swapService.configRequests()
        XCTAssertEqual(configRequests, [.init(walletId: "wallet", fromAssetId: nil, toAssetId: nil)])
        let catalogAssetRequests = await swapService.catalogAssetRequests()
        XCTAssertTrue(
            catalogAssetRequests.isEmpty,
            "The default pair assets come with the configuration and need no extra lookup"
        )
        let listCrossSwapAssetsRequestCount = await swapService.listCrossSwapAssetsRequestCount()
        XCTAssertEqual(listCrossSwapAssetsRequestCount, 0)
    }

    func test_loadIgnoresDuplicateAssetIdsKeepingFirstValues() async throws {
        let walletAsset = asset(
            assetId: "ton/mainnet/coin",
            symbol: "TON",
            decimals: 9,
            balance: 42
        )
        let duplicateWalletAsset = asset(
            assetId: "ton/mainnet/coin",
            symbol: "TON_DUPLICATE",
            decimals: 9,
            balance: 99
        )
        let multichainService = DefaultAssetsMultichainServiceSpy(
            walletAssetsResult: .success(
                .init(
                    assets: [walletAsset, duplicateWalletAsset],
                    nextCursor: nil,
                    fiatPrice: [:]
                )
            )
        )
        let swapService = DefaultAssetsSwapServiceSpy(
            catalogResult: .success([
                swapAsset(assetId: "eth/mainnet/coin", symbol: "ETH", decimals: 18, chainId: "eth/mainnet"),
                swapAsset(
                    assetId: "eth/mainnet/coin",
                    symbol: "ETH_DUPLICATE",
                    decimals: 18,
                    chainId: "eth/mainnet"
                ),
                swapAsset(assetId: "ton/mainnet/coin", symbol: "TON", decimals: 9, chainId: "ton/mainnet"),
                swapAsset(
                    assetId: "ton/mainnet/coin",
                    symbol: "TON_DUPLICATE",
                    decimals: 9,
                    chainId: "ton/mainnet"
                ),
            ]),
            configResult: .success(makeConfig())
        )

        let result = try await makeService(
            multichainService: multichainService,
            swapService: swapService
        ).load()

        XCTAssertEqual(result.catalog.count, 2)
        XCTAssertEqual(result.catalog["eth/mainnet/coin"]?.symbol, "ETH")
        XCTAssertEqual(result.catalog["ton/mainnet/coin"]?.symbol, "TON")
        XCTAssertEqual(result.sendAsset.asset.symbol, "TON")
        XCTAssertEqual(result.sendAsset.balance, 42)
        XCTAssertEqual(result.receiveAsset.asset.symbol, "ETH")
    }

    func test_loadThrowsWhenSourceAssetIsMissingFromConfiguration() async {
        let multichainService = DefaultAssetsMultichainServiceSpy(
            walletAssetsResult: .success(.init(assets: [], nextCursor: nil, fiatPrice: [:]))
        )
        let swapService = DefaultAssetsSwapServiceSpy(
            catalogResult: .success([
                swapAsset(assetId: "eth/mainnet/coin", symbol: "ETH", decimals: 18, chainId: "eth/mainnet"),
            ]),
            configResult: .success(makeConfig())
        )

        do {
            _ = try await makeService(
                multichainService: multichainService,
                swapService: swapService
            ).load()
            XCTFail("Expected missing source error")
        } catch MultichainSwapInitialAssetsError.missingSourceAsset {
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func test_loadThrowsWhenDestinationAssetIsMissingFromConfiguration() async {
        let multichainService = DefaultAssetsMultichainServiceSpy(
            walletAssetsResult: .success(.init(assets: [], nextCursor: nil, fiatPrice: [:]))
        )
        let swapService = DefaultAssetsSwapServiceSpy(
            catalogResult: .success([
                swapAsset(assetId: "ton/mainnet/coin", symbol: "TON", decimals: 9, chainId: "ton/mainnet"),
            ]),
            configResult: .success(makeConfig())
        )

        do {
            _ = try await makeService(
                multichainService: multichainService,
                swapService: swapService
            ).load()
            XCTFail("Expected missing destination error")
        } catch MultichainSwapInitialAssetsError.missingDestinationAsset {
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func test_loadWithReceiveInitialSelectionRequestsSelectedAssetAsDestination() async throws {
        let multichainService = DefaultAssetsMultichainServiceSpy(
            walletAssetsResult: .success(.init(assets: [], nextCursor: nil, fiatPrice: [:]))
        )
        let swapService = DefaultAssetsSwapServiceSpy(
            catalogResult: .success([
                swapAsset(assetId: "eth/mainnet/coin", symbol: "ETH", decimals: 18, chainId: "eth/mainnet"),
                swapAsset(assetId: "ton/mainnet/coin", symbol: "TON", decimals: 9, chainId: "ton/mainnet"),
                swapAsset(assetId: "base/mainnet/coin", symbol: "BASE", decimals: 18, chainId: "base/mainnet"),
            ]),
            configResult: .success(
                makeConfig(
                    sourceAssetId: "eth/mainnet/coin",
                    destinationAssetId: "base/mainnet/coin"
                )
            )
        )

        let result = try await makeService(
            multichainService: multichainService,
            swapService: swapService,
            initialSelection: MultichainSwapInitialAssetSelection(
                assetId: "base/mainnet/coin",
                side: .receive
            )
        ).load()

        XCTAssertEqual(result.sendAsset.asset.assetId, "eth/mainnet/coin")
        XCTAssertEqual(result.receiveAsset.asset.assetId, "base/mainnet/coin")
        XCTAssertFalse(result.hasUnavailableInitialSelection)
        let configRequests = await swapService.configRequests()
        XCTAssertEqual(
            configRequests,
            [.init(walletId: "wallet", fromAssetId: nil, toAssetId: "base/mainnet/coin")]
        )
        let catalogAssetRequests = await swapService.catalogAssetRequests()
        XCTAssertEqual(
            catalogAssetRequests,
            ["base/mainnet/coin"],
            "Only the requested asset is validated before the config request"
        )
    }

    func test_loadWithSendInitialSelectionRequestsSelectedAssetAsSource() async throws {
        let multichainService = DefaultAssetsMultichainServiceSpy(
            walletAssetsResult: .success(.init(assets: [], nextCursor: nil, fiatPrice: [:]))
        )
        let swapService = DefaultAssetsSwapServiceSpy(
            catalogResult: .success([
                swapAsset(assetId: "eth/mainnet/coin", symbol: "ETH", decimals: 18, chainId: "eth/mainnet"),
                swapAsset(assetId: "ton/mainnet/coin", symbol: "TON", decimals: 9, chainId: "ton/mainnet"),
                swapAsset(assetId: "base/mainnet/coin", symbol: "BASE", decimals: 18, chainId: "base/mainnet"),
            ]),
            configResult: .success(
                makeConfig(
                    sourceAssetId: "base/mainnet/coin",
                    destinationAssetId: "eth/mainnet/coin"
                )
            )
        )

        let result = try await makeService(
            multichainService: multichainService,
            swapService: swapService,
            initialSelection: MultichainSwapInitialAssetSelection(
                assetId: "base/mainnet/coin",
                side: .send
            )
        ).load()

        XCTAssertEqual(result.sendAsset.asset.assetId, "base/mainnet/coin")
        XCTAssertEqual(result.receiveAsset.asset.assetId, "eth/mainnet/coin")
        XCTAssertFalse(result.hasUnavailableInitialSelection)
        let configRequests = await swapService.configRequests()
        XCTAssertEqual(
            configRequests,
            [.init(walletId: "wallet", fromAssetId: "base/mainnet/coin", toAssetId: nil)]
        )
        let catalogAssetRequests = await swapService.catalogAssetRequests()
        XCTAssertEqual(
            catalogAssetRequests,
            ["base/mainnet/coin"]
        )
    }

    func test_loadWithBothInitialSelectionsRequestsBothAssets() async throws {
        let multichainService = DefaultAssetsMultichainServiceSpy(
            walletAssetsResult: .success(.init(assets: [], nextCursor: nil, fiatPrice: [:]))
        )
        let swapService = DefaultAssetsSwapServiceSpy(
            catalogResult: .success([
                swapAsset(assetId: "ton/mainnet/coin", symbol: "TON", decimals: 9, chainId: "ton/mainnet"),
                swapAsset(assetId: "base/mainnet/coin", symbol: "BASE", decimals: 18, chainId: "base/mainnet"),
            ]),
            configResult: .success(
                makeConfig(
                    sourceAssetId: "ton/mainnet/coin",
                    destinationAssetId: "base/mainnet/coin"
                )
            )
        )

        let result = try await makeService(
            multichainService: multichainService,
            swapService: swapService,
            initialSelection: .init(
                sendAssetId: "ton/mainnet/coin",
                receiveAssetId: "base/mainnet/coin"
            )
        ).load()

        XCTAssertEqual(result.sendAsset.asset.assetId, "ton/mainnet/coin")
        XCTAssertEqual(result.receiveAsset.asset.assetId, "base/mainnet/coin")
        XCTAssertFalse(result.hasUnavailableInitialSelection)
        let configRequests = await swapService.configRequests()
        XCTAssertEqual(
            configRequests,
            [.init(walletId: "wallet", fromAssetId: "ton/mainnet/coin", toAssetId: "base/mainnet/coin")]
        )
        let catalogAssetRequests = await swapService.catalogAssetRequests()
        XCTAssertEqual(
            catalogAssetRequests.sorted(),
            ["base/mainnet/coin", "ton/mainnet/coin"],
            "Both sides are validated concurrently, so only the multiset is deterministic"
        )
    }

    func test_loadResolvesChainScopedDeeplinkAssetsBeforeConfigRequest() async throws {
        let usdtAssetId = "tron/mainnet/trc20/TR7NHqjeKQxGTCi8q8ZY4pL8otSzgjLj6t"
        let multichainService = DefaultAssetsMultichainServiceSpy(
            walletAssetsResult: .success(.init(assets: [], nextCursor: nil, fiatPrice: [:]))
        )
        let swapService = DefaultAssetsSwapServiceSpy(
            catalogResult: .success([
                swapAsset(assetId: "ton/mainnet/coin", symbol: "TON", decimals: 9, chainId: "ton/mainnet"),
                swapAsset(assetId: usdtAssetId, symbol: "USDT", decimals: 6, chainId: "tron/mainnet"),
            ]),
            configResult: .success(
                makeConfig(
                    sourceAssetId: "ton/mainnet/coin",
                    destinationAssetId: usdtAssetId
                )
            )
        )
        let selection = try XCTUnwrap(
            MultichainSwapInitialAssetSelection(
                deeplinkSendAssetId: "ton/mainnet",
                deeplinkReceiveAssetId: "tron/mainnet/trc20"
            )
        )

        let result = try await makeService(
            multichainService: multichainService,
            swapService: swapService,
            initialSelection: selection
        ).load()

        XCTAssertEqual(result.sendAsset.asset.assetId, "ton/mainnet/coin")
        XCTAssertEqual(result.receiveAsset.asset.assetId, usdtAssetId)
        let configRequests = await swapService.configRequests()
        XCTAssertEqual(
            configRequests,
            [.init(walletId: "wallet", fromAssetId: "ton/mainnet/coin", toAssetId: usdtAssetId)]
        )
        let catalogAssetRequests = await swapService.catalogAssetRequests()
        XCTAssertEqual(
            catalogAssetRequests,
            ["ton/mainnet/coin"],
            "The chain-scoped asset comes from the chain catalog and needs no extra lookup"
        )
        let listCrossSwapAssetsRequestCount = await swapService.listCrossSwapAssetsRequestCount()
        XCTAssertEqual(listCrossSwapAssetsRequestCount, 1)
    }

    func test_loadResolvesTokenDeeplinkAssetWithChecksummedAddressAndAliasStandard() async throws {
        let usdtAssetId = "eth/mainnet/erc20/0xdac17f958d2ee523a2206206994597c13d831ec7"
        let multichainService = DefaultAssetsMultichainServiceSpy(
            walletAssetsResult: .success(.init(assets: [], nextCursor: nil, fiatPrice: [:]))
        )
        let swapService = DefaultAssetsSwapServiceSpy(
            catalogResult: .success([
                swapAsset(assetId: "eth/mainnet/coin", symbol: "ETH", decimals: 18, chainId: "eth/mainnet"),
                swapAsset(assetId: usdtAssetId, symbol: "USDT", decimals: 6, chainId: "eth/mainnet"),
            ]),
            configResult: .success(
                makeConfig(
                    sourceAssetId: usdtAssetId,
                    destinationAssetId: "eth/mainnet/coin"
                )
            )
        )
        let selection = try XCTUnwrap(
            MultichainSwapInitialAssetSelection(
                deeplinkSendAssetId: "eth/mainnet/token/0xdAC17F958D2ee523a2206206994597C13D831ec7",
                deeplinkReceiveAssetId: "eth/mainnet/coin"
            )
        )

        let result = try await makeService(
            multichainService: multichainService,
            swapService: swapService,
            initialSelection: selection
        ).load()

        XCTAssertEqual(result.sendAsset.asset.assetId, usdtAssetId)
        XCTAssertEqual(result.receiveAsset.asset.assetId, "eth/mainnet/coin")
        XCTAssertFalse(result.hasUnavailableInitialSelection)
        let configRequests = await swapService.configRequests()
        XCTAssertEqual(
            configRequests,
            [.init(walletId: "wallet", fromAssetId: usdtAssetId, toAssetId: "eth/mainnet/coin")]
        )
        let listCrossSwapAssetsRequestCount = await swapService.listCrossSwapAssetsRequestCount()
        XCTAssertEqual(
            listCrossSwapAssetsRequestCount,
            1,
            "The generic token standard is resolved through the chain catalog"
        )
        let catalogAssetRequests = await swapService.catalogAssetRequests()
        XCTAssertEqual(
            catalogAssetRequests,
            ["eth/mainnet/coin"],
            "Only the directly addressable deeplink side needs a lookup"
        )
    }

    func test_loadDoesNotResolveUnknownTokenStandardByAddress() async throws {
        let usdtAddress = "0xdac17f958d2ee523a2206206994597c13d831ec7"
        let multichainService = DefaultAssetsMultichainServiceSpy(
            walletAssetsResult: .success(.init(assets: [], nextCursor: nil, fiatPrice: [:]))
        )
        let swapService = DefaultAssetsSwapServiceSpy(
            catalogResult: .success([
                swapAsset(assetId: "ton/mainnet/coin", symbol: "TON", decimals: 9, chainId: "ton/mainnet"),
                swapAsset(assetId: "eth/mainnet/coin", symbol: "ETH", decimals: 18, chainId: "eth/mainnet"),
                swapAsset(
                    assetId: "eth/mainnet/erc20/\(usdtAddress)",
                    symbol: "USDT",
                    decimals: 6,
                    chainId: "eth/mainnet"
                ),
            ]),
            configResult: .success(makeConfig())
        )
        let selection = try XCTUnwrap(
            MultichainSwapInitialAssetSelection(
                deeplinkSendAssetId: "eth/mainnet/dick/\(usdtAddress)",
                deeplinkReceiveAssetId: nil
            )
        )

        let result = try await makeService(
            multichainService: multichainService,
            swapService: swapService,
            initialSelection: selection
        ).load()

        XCTAssertEqual(result.sendAsset.asset.assetId, "ton/mainnet/coin")
        XCTAssertTrue(result.hasUnavailableInitialSelection)
        let configRequests = await swapService.configRequests()
        XCTAssertEqual(
            configRequests,
            [.init(walletId: "wallet", fromAssetId: nil, toAssetId: nil)]
        )
        let listCrossSwapAssetsRequestCount = await swapService.listCrossSwapAssetsRequestCount()
        XCTAssertEqual(listCrossSwapAssetsRequestCount, 0)
    }

    func test_loadPropagatesSelectedAssetLookupFailure() async {
        let expectedError = MultichainSwapAPIError.internalServerError(
            message: "Unavailable",
            code: nil,
            requestId: nil
        )
        let multichainService = DefaultAssetsMultichainServiceSpy(
            walletAssetsResult: .success(.init(assets: [], nextCursor: nil, fiatPrice: [:]))
        )
        let swapService = DefaultAssetsSwapServiceSpy(
            catalogResult: .failure(expectedError),
            configResult: .success(makeConfig())
        )

        do {
            _ = try await makeService(
                multichainService: multichainService,
                swapService: swapService,
                initialSelection: .init(assetId: "eth/mainnet/coin", side: .send)
            ).load()
            XCTFail("Expected asset lookup error")
        } catch let error as MultichainSwapAPIError {
            XCTAssertEqual(error, expectedError)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }

        let configRequests = await swapService.configRequests()
        XCTAssertTrue(configRequests.isEmpty)
    }

    func test_loadResolvesJettonDeeplinkAssetWithFriendlyAddress() async throws {
        let usdtAssetId = "ton/mainnet/jetton/0:b113a994b5024a16719f69139328eb759596c38a25f59028b146fecdc3621dfe"
        let multichainService = DefaultAssetsMultichainServiceSpy(
            walletAssetsResult: .success(.init(assets: [], nextCursor: nil, fiatPrice: [:]))
        )
        let swapService = DefaultAssetsSwapServiceSpy(
            catalogResult: .success([
                swapAsset(assetId: "ton/mainnet/coin", symbol: "TON", decimals: 9, chainId: "ton/mainnet"),
                swapAsset(assetId: usdtAssetId, symbol: "USDT", decimals: 6, chainId: "ton/mainnet"),
            ]),
            configResult: .success(
                makeConfig(
                    sourceAssetId: "ton/mainnet/coin",
                    destinationAssetId: usdtAssetId
                )
            )
        )
        let selection = try XCTUnwrap(
            MultichainSwapInitialAssetSelection(
                deeplinkSendAssetId: nil,
                deeplinkReceiveAssetId: "ton/mainnet/jetton/EQCxE6mUtQJKFnGfaROTKOt1lZbDiiX1kCixRv7Nw2Id_sDs"
            )
        )

        let result = try await makeService(
            multichainService: multichainService,
            swapService: swapService,
            initialSelection: selection
        ).load()

        XCTAssertEqual(result.receiveAsset.asset.assetId, usdtAssetId)
        XCTAssertFalse(result.hasUnavailableInitialSelection)
        let configRequests = await swapService.configRequests()
        XCTAssertEqual(
            configRequests,
            [.init(walletId: "wallet", fromAssetId: nil, toAssetId: usdtAssetId)]
        )
        let listCrossSwapAssetsRequestCount = await swapService.listCrossSwapAssetsRequestCount()
        XCTAssertEqual(
            listCrossSwapAssetsRequestCount,
            0,
            "A normalized address hits the direct lookup"
        )
    }

    func test_loadFlagsUnavailableSelectionWhenDeeplinkAssetIsUnknown() async throws {
        let multichainService = DefaultAssetsMultichainServiceSpy(
            walletAssetsResult: .success(.init(assets: [], nextCursor: nil, fiatPrice: [:]))
        )
        let swapService = DefaultAssetsSwapServiceSpy(
            catalogResult: .success([
                swapAsset(assetId: "ton/mainnet/coin", symbol: "TON", decimals: 9, chainId: "ton/mainnet"),
                swapAsset(assetId: "base/mainnet/coin", symbol: "BASE", decimals: 18, chainId: "base/mainnet"),
            ]),
            configResult: .success(
                makeConfig(
                    sourceAssetId: "base/mainnet/coin",
                    destinationAssetId: "ton/mainnet/coin"
                )
            )
        )
        let selection = try XCTUnwrap(
            MultichainSwapInitialAssetSelection(
                deeplinkSendAssetId: "base/mainnet/coin",
                deeplinkReceiveAssetId: "eth/mainnet/dick"
            )
        )

        let result = try await makeService(
            multichainService: multichainService,
            swapService: swapService,
            initialSelection: selection
        ).load()

        XCTAssertTrue(result.hasUnavailableInitialSelection)
        let configRequests = await swapService.configRequests()
        XCTAssertEqual(
            configRequests,
            [.init(walletId: "wallet", fromAssetId: "base/mainnet/coin", toAssetId: nil)],
            "An unknown asset must not reach the config request as-is"
        )
    }

    func test_loadFlagsUnavailableSelectionWhenChainIsMissingFromWallet() async throws {
        let multichainService = DefaultAssetsMultichainServiceSpy(
            walletAssetsResult: .success(.init(assets: [], nextCursor: nil, fiatPrice: [:]))
        )
        let swapService = DefaultAssetsSwapServiceSpy(
            catalogResult: .success([
                swapAsset(assetId: "ton/mainnet/coin", symbol: "TON", decimals: 9, chainId: "ton/mainnet"),
                swapAsset(assetId: "bsc/mainnet/coin", symbol: "BNB", decimals: 18, chainId: "bsc/mainnet"),
                swapAsset(assetId: "eth/mainnet/coin", symbol: "ETH", decimals: 18, chainId: "eth/mainnet"),
            ]),
            configResult: .success(makeConfig())
        )
        let selection = try XCTUnwrap(
            MultichainSwapInitialAssetSelection(
                deeplinkSendAssetId: "bsc/mainnet/coin",
                deeplinkReceiveAssetId: nil
            )
        )

        let result = try await makeService(
            multichainService: multichainService,
            swapService: swapService,
            initialSelection: selection
        ).load()

        XCTAssertTrue(result.hasUnavailableInitialSelection)
        let configRequests = await swapService.configRequests()
        XCTAssertEqual(
            configRequests,
            [.init(walletId: "wallet", fromAssetId: nil, toAssetId: nil)]
        )
    }

    func test_loadDoesNotFlagLegacySymbolSelection() async throws {
        let multichainService = DefaultAssetsMultichainServiceSpy(
            walletAssetsResult: .success(.init(assets: [], nextCursor: nil, fiatPrice: [:]))
        )
        let swapService = DefaultAssetsSwapServiceSpy(
            catalogResult: .success([
                swapAsset(assetId: "ton/mainnet/coin", symbol: "TON", decimals: 9, chainId: "ton/mainnet"),
                swapAsset(assetId: "eth/mainnet/coin", symbol: "ETH", decimals: 18, chainId: "eth/mainnet"),
            ]),
            configResult: .success(makeConfig())
        )

        let result = try await makeService(
            multichainService: multichainService,
            swapService: swapService,
            initialSelection: .init(sendAssetId: "USDT", receiveAssetId: "TON")
        ).load()

        XCTAssertFalse(
            result.hasUnavailableInitialSelection,
            "Legacy symbol deeplinks are expected to fall back to the default pair silently"
        )
    }

    func test_loadWithInitialSelectionKeepsSelectedWalletBalance() async throws {
        let selectedWalletAsset = asset(
            assetId: "base/mainnet/coin",
            symbol: "BASE",
            decimals: 18,
            balance: 77
        )
        let multichainService = DefaultAssetsMultichainServiceSpy(
            walletAssetsResult: .success(.init(assets: [selectedWalletAsset], nextCursor: nil, fiatPrice: [:]))
        )
        let swapService = DefaultAssetsSwapServiceSpy(
            catalogResult: .success([
                swapAsset(assetId: "eth/mainnet/coin", symbol: "ETH", decimals: 18, chainId: "eth/mainnet"),
                swapAsset(assetId: "ton/mainnet/coin", symbol: "TON", decimals: 9, chainId: "ton/mainnet"),
                swapAsset(assetId: "base/mainnet/coin", symbol: "BASE", decimals: 18, chainId: "base/mainnet"),
            ]),
            configResult: .success(
                makeConfig(
                    sourceAssetId: "base/mainnet/coin",
                    destinationAssetId: "eth/mainnet/coin"
                )
            )
        )

        let result = try await makeService(
            multichainService: multichainService,
            swapService: swapService,
            initialSelection: MultichainSwapInitialAssetSelection(
                assetId: "base/mainnet/coin",
                side: .send
            )
        ).load()

        XCTAssertEqual(result.sendAsset, selectedWalletAsset)
        XCTAssertEqual(result.sendAsset.balance, 77)
    }

    func test_loadThrowsWhenConfigRequestFails() async {
        let multichainService = DefaultAssetsMultichainServiceSpy(
            walletAssetsResult: .success(.init(assets: [], nextCursor: nil, fiatPrice: [:]))
        )
        let swapService = DefaultAssetsSwapServiceSpy(
            catalogResult: .success([
                swapAsset(assetId: "eth/mainnet/coin", symbol: "ETH", decimals: 18, chainId: "eth/mainnet"),
                swapAsset(assetId: "ton/mainnet/coin", symbol: "TON", decimals: 9, chainId: "ton/mainnet"),
            ]),
            configResult: .failure(StubError.unimplemented)
        )

        do {
            _ = try await makeService(
                multichainService: multichainService,
                swapService: swapService
            ).load()
            XCTFail("Expected config request error")
        } catch StubError.unimplemented {
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func test_usdFiatRateDerivesFromFirstWalletAssetWithBothPrices() {
        let priceless = asset(assetId: "a/mainnet/coin", symbol: "A", decimals: 9)
        let priced = asset(
            assetId: "b/mainnet/coin",
            symbol: "B",
            decimals: 9,
            prices: ["eur": 1.5, "usd": 2.0]
        )

        XCTAssertEqual(
            MultichainSwapFiatRateResolver(displayCurrency: .EUR).walletDerivedUsdFiatRate(
                walletAssets: [priceless, priced]
            ),
            Decimal(string: "0.75")
        )
        XCTAssertNil(
            MultichainSwapFiatRateResolver(displayCurrency: .EUR).walletDerivedUsdFiatRate(
                walletAssets: [priceless]
            )
        )
        XCTAssertEqual(
            MultichainSwapFiatRateResolver(displayCurrency: .EUR).walletDerivedUsdFiatRate(
                walletAssets: [
                    asset(
                        assetId: "c/mainnet/coin",
                        symbol: "C",
                        decimals: 9,
                        prices: ["EUR": 1.5, "USD": 2.0]
                    ),
                ]
            ),
            Decimal(string: "0.75"),
            "Backend price keys are not consistent about casing"
        )
        XCTAssertEqual(
            MultichainSwapFiatRateResolver(displayCurrency: .USD).walletDerivedUsdFiatRate(
                walletAssets: []
            ),
            1
        )
    }
}

private extension MultichainSwapDefaultAssetsServiceTests {
    func makeService(
        multichainService: MultichainService,
        swapService: MultichainSwapService,
        initialSelection: MultichainSwapInitialAssetSelection? = nil
    ) -> DefaultMultichainSwapDefaultAssetsService {
        DefaultMultichainSwapDefaultAssetsService(
            multichainState: MultichainWalletState(
                walletId: "wallet",
                addresses: [
                    .init(chain: .eth, address: "0xwallet"),
                    .init(chain: .base, address: "0xwallet"),
                    .init(chain: .ton, address: "tonwallet"),
                    .init(chain: .tron, address: "tronwallet"),
                ]
            ),
            multichainService: multichainService,
            multichainSwapService: swapService,
            currencyStore: makeCurrencyStore(),
            initialSelection: initialSelection
        )
    }

    func makeCurrencyStore() -> CurrencyStore {
        CurrencyStore(
            keeperInfoStore: KeeperInfoStore(
                keeperInfoRepository: KeeperInfoRepositoryMock(keeperInfo: nil)
            )
        )
    }

    func makeConfig(
        sourceAssetId: String = "ton/mainnet/coin",
        destinationAssetId: String = "eth/mainnet/coin",
        chains: [String: MultichainSwapSlippageOptions] = [:]
    ) -> DefaultAssetsSwapServiceSpy.ConfigPlan {
        .init(
            sourceAssetId: sourceAssetId,
            destinationAssetId: destinationAssetId,
            slippage: .init(chains: chains)
        )
    }

    func asset(
        assetId: String,
        symbol: String,
        decimals: Int,
        balance: BigUInt = .zero,
        prices: [String: Double] = [:]
    ) -> MultichainAsset {
        MultichainAsset(
            asset: MultichainAssetDetails(
                assetId: assetId,
                name: symbol,
                symbol: symbol,
                decimals: decimals,
                image: ""
            ),
            price: MultichainAssetPrice(
                prices: prices,
                diff24h: [:],
                diff7d: [:],
                diff30d: [:]
            ),
            balance: balance
        )
    }

    func swapAsset(
        assetId: String,
        symbol: String,
        decimals: Int,
        chainId: String
    ) -> MultichainSwapAsset {
        MultichainSwapAsset(
            assetId: assetId,
            symbol: symbol,
            name: symbol,
            decimals: decimals,
            image: nil,
            chainFamily: chainId.split(separator: "/").first.map(String.init) ?? "",
            supportedAggregators: ["test"],
            usdPrice: 1
        )
    }
}

private actor DefaultAssetsMultichainServiceSpy: MultichainService {
    struct WalletAssetsRequest {
        let walletId: String
        let currencies: [String]
        let showHidden: Bool?
    }

    private let walletAssetsResult: Result<MultichainWalletAssetsPage, MultichainServiceError>
    private var recordedWalletAssetsRequests = [WalletAssetsRequest]()

    init(walletAssetsResult: Result<MultichainWalletAssetsPage, MultichainServiceError>) {
        self.walletAssetsResult = walletAssetsResult
    }

    func walletAssetsRequests() -> [WalletAssetsRequest] {
        recordedWalletAssetsRequests
    }

    func getWalletAssets(
        state: MultichainWalletState,
        currencies: [String],
        assetIds _: [String]?,
        capabilities _: [MultichainAssetCapability]?,
        chain _: MultichainChain?,
        search _: String?,
        availableOnly _: Bool?,
        showHidden: Bool?,
        hideDust _: Bool?,
        limit _: Int?,
        cursor _: String?
    ) async throws(MultichainServiceError) -> MultichainWalletAssetsPage {
        recordedWalletAssetsRequests.append(
            WalletAssetsRequest(
                walletId: state.walletId,
                currencies: currencies,
                showHidden: showHidden
            )
        )
        return try walletAssetsResult.get()
    }

    func healthcheck() async throws(MultichainServiceError) -> MultichainHealth {
        throw .apiError(message: "Unimplemented")
    }

    func searchAssets(
        currencies _: [String],
        chain _: MultichainChain?,
        search _: String?,
        sort _: MultichainAssetSearchSort,
        limit _: Int?,
        cursor _: String?
    ) async throws(MultichainServiceError) -> (assets: [MultichainAsset], nextCursor: String?) {
        throw .apiError(message: "Unimplemented")
    }

    func getWallet(walletId _: String) async throws(MultichainServiceError) -> MultichainRegisteredWallet {
        throw .apiError(message: "Unimplemented")
    }

    func getWalletSyncStatus(walletId _: String) async throws(MultichainServiceError) -> MultichainWalletSyncStatus {
        throw .apiError(message: "Unimplemented")
    }

    func getWalletChallenge() async throws(MultichainServiceError) -> MultichainWalletChallenge {
        throw .apiError(message: "Unimplemented")
    }

    func saveWalletAssetsFilters(walletId _: String, changes _: [MultichainAssetFilterChange]) async throws(MultichainServiceError) {
        throw .apiError(message: "Unimplemented")
    }

    func getWalletActivities(
        state _: MultichainWalletState,
        limit _: Int?,
        cursor _: String?,
        chain _: MultichainChain?,
        assetId _: String?,
        activityTypeFilter _: MultichainActivityTypeFilter?,
        showPerps _: Bool?,
        hideDust _: Bool?
    ) async throws(MultichainServiceError) -> MultichainWalletActivitiesPage {
        throw .apiError(message: "Unimplemented")
    }

    func registerWallet(walletId _: String, addresses _: [MultichainWalletAddress]) async throws(MultichainServiceError) -> MultichainRegisteredWallet {
        throw .apiError(message: "Unimplemented")
    }

    func broadcastTx(chain _: MultichainChain, signedTransaction _: Data) async throws(MultichainServiceError) -> MultichainBroadcastResult {
        throw .apiError(message: "Unimplemented")
    }

    func getFees(chain _: MultichainChain) async throws(MultichainServiceError) -> MultichainFeeEstimate {
        throw .apiError(message: "Unimplemented")
    }

    func getWalletRaffles(
        walletId _: String,
        lang _: String?,
        ids _: [String]?,
        debugNow _: Date?,
        isNewUser _: Bool
    ) async throws(MultichainServiceError) -> [MultichainRaffle] {
        throw .apiError(message: "Unimplemented")
    }

    func completeRaffleMigration(walletId _: String) async throws(MultichainServiceError) {
        throw .apiError(message: "Unimplemented")
    }

    func markRaffleImport(walletId _: String, importedWalletId _: String) async throws(MultichainServiceError) {
        throw .apiError(message: "Unimplemented")
    }

    func forcePickRaffleWinners(
        raffleId _: String,
        walletId _: String?,
        prizeId _: String?
    ) async throws(MultichainServiceError) {
        throw .apiError(message: "Unimplemented")
    }
}

private actor DefaultAssetsSwapServiceSpy: MultichainSwapService {
    struct ConfigRequest: Equatable {
        let walletId: String
        let fromAssetId: String?
        let toAssetId: String?
    }

    /// The backend embeds the default pair assets into the configuration, so the spy resolves
    /// them from the same catalog it answers asset lookups from.
    struct ConfigPlan {
        let sourceAssetId: String
        let destinationAssetId: String
        let slippage: MultichainSwapSlippage
    }

    private let catalogResult: Result<[MultichainSwapAsset], Error>
    private let configResult: Result<ConfigPlan, Error>
    private var recordedCatalogAssetRequests = [String]()
    private var recordedConfigRequests = [ConfigRequest]()
    private var listCrossSwapAssetsRequests = 0

    init(
        catalogResult: Result<[MultichainSwapAsset], Error>,
        configResult: Result<ConfigPlan, Error>
    ) {
        self.catalogResult = catalogResult
        self.configResult = configResult
    }

    func catalogAssetRequests() -> [String] {
        recordedCatalogAssetRequests
    }

    func listCrossSwapAssetsRequestCount() -> Int {
        listCrossSwapAssetsRequests
    }

    func configRequests() -> [ConfigRequest] {
        recordedConfigRequests
    }

    func listCrossSwapAssets(query _: MultichainSwapAssetsQuery) async throws -> [MultichainSwapAsset] {
        listCrossSwapAssetsRequests += 1
        return try catalogResult.get()
    }

    func getCrossSwapConfig(
        walletId: String,
        fromAssetId: String?,
        toAssetId: String?
    ) async throws -> MultichainSwapConfig {
        recordedConfigRequests.append(
            .init(
                walletId: walletId,
                fromAssetId: fromAssetId,
                toAssetId: toAssetId
            )
        )
        let plan = try configResult.get()
        return MultichainSwapConfig(
            defaultPair: MultichainSwapDefaultPair(
                sourceAsset: catalogAsset(assetId: plan.sourceAssetId),
                destinationAsset: catalogAsset(assetId: plan.destinationAssetId)
            ),
            slippage: plan.slippage
        )
    }

    func getCrossSwapAsset(assetId: String) async throws -> MultichainSwapAsset {
        recordedCatalogAssetRequests.append(assetId)
        let catalogAssets = try catalogResult.get()
        guard let asset = catalogAssets.first(where: { $0.assetId == assetId }) else {
            throw MultichainSwapAPIError.notFound(
                message: assetId,
                code: nil,
                requestId: nil
            )
        }
        return asset
    }

    func createCrossSwapQuote(
        request _: MultichainSwapQuoteRequest,
        walletId _: String?
    ) async throws(MultichainSwapAPIError) -> MultichainSwapQuote {
        throw .unknown(statusCode: -1)
    }

    private func catalogAsset(assetId: String) -> MultichainSwapAsset? {
        guard case let .success(assets) = catalogResult else {
            return nil
        }
        return assets.first { $0.assetId == assetId }
    }

    func prepareCrossSwapRoute(
        routeId _: String,
        request _: MultichainSwapPrepareRouteRequest?,
        walletId: String?
    ) async throws -> MultichainSwapPrepare {
        throw StubError.unimplemented
    }
}

private final class KeeperInfoRepositoryMock: KeeperInfoRepository {
    enum Error: Swift.Error {
        case noKeeperInfo
    }

    var keeperInfo: KeeperInfo?

    init(keeperInfo: KeeperInfo?) {
        self.keeperInfo = keeperInfo
    }

    func getKeeperInfo() throws -> KeeperInfo {
        guard let keeperInfo else {
            throw Error.noKeeperInfo
        }
        return keeperInfo
    }

    func saveKeeperInfo(_ keeperInfo: KeeperInfo) throws {
        self.keeperInfo = keeperInfo
    }

    func removeKeeperInfo() throws {
        keeperInfo = nil
    }
}

private enum StubError: Error {
    case unimplemented
}
