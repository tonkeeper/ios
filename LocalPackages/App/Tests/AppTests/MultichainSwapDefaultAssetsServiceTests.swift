@testable import App
import BigInt
import Foundation
@testable import KeeperCore
import TonSwift
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
        XCTAssertEqual(result.slippage, config.slippage)

        let requests = await multichainService.walletAssetsRequests()
        XCTAssertEqual(requests.map(\.walletId), ["wallet"])
        XCTAssertEqual(requests.map(\.currencies), [["usd"]])
        XCTAssertEqual(requests.map(\.showHidden), [false])
        let configRequests = await swapService.configRequests()
        XCTAssertEqual(configRequests, [.init(walletId: "wallet", fromAssetId: nil, toAssetId: nil)])
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
        let assetDetailsService = DefaultAssetsTradingAssetDetailsServiceSpy(
            loadedDetailsResults: ["eth/mainnet/dick/\(usdtAddress)": .failure(.notFound)]
        )

        let result = try await makeService(
            multichainService: multichainService,
            swapService: swapService,
            assetDetailsService: assetDetailsService,
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
        let assetDetailsService = DefaultAssetsTradingAssetDetailsServiceSpy(
            loadedDetailsResults: ["eth/mainnet/coin": .failure(.networkError)]
        )

        do {
            _ = try await makeService(
                multichainService: multichainService,
                swapService: swapService,
                assetDetailsService: assetDetailsService,
                initialSelection: .init(assetId: "eth/mainnet/coin", side: .send)
            ).load()
            XCTFail("Expected asset lookup error")
        } catch TradingAssetDetailsServiceFailure.networkError {
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

    func test_loadFlagsUnavailableSelectionWhenTradingDetailsDoNotSupportSwap() async throws {
        let selectedAssetId = "base/mainnet/coin"
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
        let assetDetailsService = DefaultAssetsTradingAssetDetailsServiceSpy(
            loadedDetailsResults: [
                selectedAssetId: .success(
                    DefaultAssetsTradingAssetDetailsServiceSpy.makeDetails(
                        assetId: selectedAssetId,
                        capabilities: []
                    )
                ),
            ]
        )

        let result = try await makeService(
            multichainService: multichainService,
            swapService: swapService,
            assetDetailsService: assetDetailsService,
            initialSelection: .init(assetId: selectedAssetId, side: .send)
        ).load()

        XCTAssertTrue(result.hasUnavailableInitialSelection)
        let loadedDetailsIds = await assetDetailsService.loadAssetDetailsIds()
        XCTAssertEqual(loadedDetailsIds, [selectedAssetId])
        let configRequests = await swapService.configRequests()
        XCTAssertEqual(
            configRequests,
            [.init(walletId: "wallet", fromAssetId: nil, toAssetId: nil)]
        )
    }

    func test_loadFlagsUnavailableSelectionWhenTradingDetailsAreNotFound() async throws {
        let selectedAssetId = "base/mainnet/coin"
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
        let assetDetailsService = DefaultAssetsTradingAssetDetailsServiceSpy(
            loadedDetailsResults: [selectedAssetId: .failure(.notFound)]
        )

        let result = try await makeService(
            multichainService: multichainService,
            swapService: swapService,
            assetDetailsService: assetDetailsService,
            initialSelection: .init(assetId: selectedAssetId, side: .receive)
        ).load()

        XCTAssertTrue(result.hasUnavailableInitialSelection)
        let loadedDetailsIds = await assetDetailsService.loadAssetDetailsIds()
        XCTAssertEqual(loadedDetailsIds, [selectedAssetId])
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

    func test_legacyPairBuildsAssetsFromDetailsAndConvertedHoldings() async throws {
        let wallet = makeLegacyWallet()
        let currencyStore = makeCurrencyStore()
        let convertedBalanceStore = makeConvertedBalanceStore()
        let convertedBalance = ConvertedBalance(
            date: .distantPast,
            currency: currencyStore.state,
            tonBalance: ConvertedTonBalance(
                tonBalance: TonBalance(amount: 2_000_000_000),
                converted: 5,
                price: 2.5,
                diff: nil
            ),
            jettonsBalance: [],
            stackingBalance: [],
            tronUSDT: ConvertedBalanceTronUSDTItem(
                amount: 1_500_000,
                converted: 1.5,
                price: 1,
                diff: nil
            ),
            tronTRX: nil,
            batteryBalance: nil
        )
        let convertedBalanceUpdated = expectation(description: "Converted balance updated")
        convertedBalanceStore.updateState {
            _ in .init(newState: [wallet: .current(convertedBalance)])
        } completion: {
            _ in convertedBalanceUpdated.fulfill()
        }
        await fulfillment(of: [convertedBalanceUpdated])

        let tonAssetId = "ton/mainnet/coin"
        let tronUsdtAssetId = "tron/mainnet/trc20/TR7NHqjeKQxGTCi8q8ZY4pL8otSzgjLj6t"
        let assetDetailsService = DefaultAssetsTradingAssetDetailsServiceSpy(
            loadedDetailsResults: [
                tonAssetId: .success(
                    DefaultAssetsTradingAssetDetailsServiceSpy.makeDetails(
                        assetId: tonAssetId,
                        symbol: "TON",
                        title: "Toncoin",
                        decimals: 9,
                        imageURL: URL(string: "https://cdn.example/ton.png")
                    )
                ),
                tronUsdtAssetId: .success(
                    DefaultAssetsTradingAssetDetailsServiceSpy.makeDetails(
                        assetId: tronUsdtAssetId,
                        symbol: "USDT",
                        title: "Tether USD",
                        decimals: 6,
                        imageURL: URL(string: "https://cdn.example/usdt.png")
                    )
                ),
            ]
        )
        let service = LegacyPairMultichainSwapDefaultAssetsService(
            wallet: wallet,
            sendAssetId: tonAssetId,
            receiveAssetId: tronUsdtAssetId,
            assetDetailsService: assetDetailsService,
            convertedBalanceStore: convertedBalanceStore,
            currencyStore: currencyStore
        )

        let result = try await service.load()

        XCTAssertEqual(result.sendAsset.asset.assetId, tonAssetId)
        XCTAssertEqual(result.sendAsset.asset.name, "Toncoin")
        XCTAssertEqual(result.sendAsset.asset.image, "https://cdn.example/ton.png")
        XCTAssertEqual(result.sendAsset.balance, 2_000_000_000)
        XCTAssertEqual(result.sendAsset.price.prices["usd"], 2.5)
        XCTAssertEqual(result.receiveAsset.asset.assetId, tronUsdtAssetId)
        XCTAssertEqual(result.receiveAsset.asset.name, "Tether USD")
        XCTAssertEqual(result.receiveAsset.asset.image, "https://cdn.example/usdt.png")
        XCTAssertEqual(result.receiveAsset.balance, 1_500_000)
        XCTAssertEqual(result.receiveAsset.price.prices["usd"], 1)
        XCTAssertNil(result.usdFiatRate)
    }

    func test_usdFiatRateDerivesFromFirstWalletAssetWithBothPrices() throws {
        let priceless = asset(assetId: "a/mainnet/coin", symbol: "A", decimals: 9)
        let priced = asset(
            assetId: "b/mainnet/coin",
            symbol: "B",
            decimals: 9,
            prices: ["eur": 1.5, "usd": 2.0]
        )

        XCTAssertEqual(
            try MultichainSwapFiatRateResolver(displayCurrency: XCTUnwrap(Currency(code: "EUR"))).walletDerivedUsdFiatRate(
                walletAssets: [priceless, priced]
            ),
            Decimal(string: "0.75")
        )
        XCTAssertNil(
            try MultichainSwapFiatRateResolver(displayCurrency: XCTUnwrap(Currency(code: "EUR"))).walletDerivedUsdFiatRate(
                walletAssets: [priceless]
            )
        )
        XCTAssertEqual(
            try MultichainSwapFiatRateResolver(displayCurrency: XCTUnwrap(Currency(code: "EUR"))).walletDerivedUsdFiatRate(
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
        assetDetailsService: TradingAssetDetailsService = DefaultAssetsTradingAssetDetailsServiceSpy(),
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
            assetDetailsService: assetDetailsService,
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

    func makeLegacyWallet() -> Wallet {
        let publicKey = PublicKey(data: Data(repeating: 0x01, count: 32))
        return Wallet(
            id: "legacy-wallet",
            identity: WalletIdentity(network: .mainnet, kind: .Regular(publicKey, .v4R2)),
            metaData: WalletMetaData(
                label: "Legacy wallet",
                tintColor: .defaultColor,
                icon: .icon(.wallet)
            ),
            setupSettings: WalletSetupSettings(isSetupFinished: true),
            batterySettings: BatterySettings()
        )
    }

    func makeConvertedBalanceStore() -> ConvertedBalanceStore {
        let keeperInfoStore = KeeperInfoStore(
            keeperInfoRepository: KeeperInfoRepositoryMock(keeperInfo: nil)
        )
        let walletsStore = WalletsStore(keeperInfoStore: keeperInfoStore)
        let balanceStore = BalanceStore(
            walletsStore: walletsStore,
            repository: LegacyPairWalletBalanceRepositoryStub()
        )
        let tonRatesStore = TonRatesStore(repository: LegacyPairRatesRepositoryStub())
        return ConvertedBalanceStore(
            walletsStore: walletsStore,
            balanceStore: balanceStore,
            tonRatesStore: tonRatesStore,
            currencyStore: makeCurrencyStore()
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
                diff7d: [:]
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

private actor DefaultAssetsTradingAssetDetailsServiceSpy: TradingAssetDetailsService {
    private let loadedDetailsResults: [String: Result<TradingAssetDetails, TradingAssetDetailsServiceFailure>]
    private var recordedLoadAssetDetailsIds = [String]()

    init(
        loadedDetailsResults: [String: Result<TradingAssetDetails, TradingAssetDetailsServiceFailure>] = [:]
    ) {
        self.loadedDetailsResults = loadedDetailsResults
    }

    func loadAssetDetailsIds() -> [String] {
        recordedLoadAssetDetailsIds
    }

    func assetDetails(for _: String) async -> TradingAssetDetails? {
        nil
    }

    func loadAssetDetails(id: String) async throws(TradingAssetDetailsServiceFailure) -> TradingAssetDetails {
        recordedLoadAssetDetailsIds.append(id)
        if let result = loadedDetailsResults[id] {
            return try result.get()
        }
        return Self.makeDetails(assetId: id)
    }
}

private extension DefaultAssetsTradingAssetDetailsServiceSpy {
    static func makeDetails(
        assetId: String,
        capabilities: Set<TradingAssetCapability> = [.swap],
        symbol: String? = nil,
        title: String? = nil,
        decimals: Int = 9,
        imageURL: URL? = nil
    ) -> TradingAssetDetails {
        TradingAssetDetails(
            id: assetId,
            assetInfo: TradingAssetInfo(
                assetId: assetId,
                category: .tokens,
                address: assetId,
                symbol: symbol ?? assetId,
                decimals: decimals,
                title: title ?? assetId,
                imageURL: imageURL,
                price: nil,
                changePercent: nil,
                changeAmount: nil,
                earnAPY: nil,
                verification: .whitelist
            ),
            capabilities: capabilities,
            aboutParagraph: "",
            overview: [],
            tradingActivity: nil,
            links: [],
            primaryActionTitle: "",
            infoSource: TradingAssetInfoSource(displayedName: "test", url: nil)
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
        showAll _: Bool?,
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
        market _: Int?,
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
    private var recordedConfigRequests = [ConfigRequest]()
    private var listCrossSwapAssetsRequests = 0

    init(
        catalogResult: Result<[MultichainSwapAsset], Error>,
        configResult: Result<ConfigPlan, Error>
    ) {
        self.catalogResult = catalogResult
        self.configResult = configResult
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

private struct LegacyPairWalletBalanceRepositoryStub: WalletBalanceRepositoryV2 {
    func getBalance(address _: FriendlyAddress) throws -> KeeperCore.WalletBalance {
        throw StubError.unimplemented
    }
}

private struct LegacyPairRatesRepositoryStub: RatesRepository {
    func saveRates(_: Rates) throws {}

    func getRates() throws -> Rates {
        Rates(ton: [], usdt: [], jettonRates: [:])
    }
}

private enum StubError: Error {
    case unimplemented
}
