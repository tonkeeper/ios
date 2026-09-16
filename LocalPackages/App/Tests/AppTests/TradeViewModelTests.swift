@testable import App
import BigInt
import Foundation
@testable import KeeperCore
import TKCore
import TonSwift
import XCTest

final class TradeViewModelTests: XCTestCase {
    @MainActor
    func test_viewDidAppear_usesMarketItemCategory() async {
        let service = TradingShelvesServiceSpy(
            snapshot: TradingShelvesSnapshot(
                generatedAt: .now,
                currency: .USD,
                shelves: [
                    TradingShelf(
                        id: "shelf",
                        title: "Shelf",
                        grids: [
                            TradingShelfGrid(
                                id: "most_traded",
                                name: "Most traded",
                                source: "api",
                                seeAllCategory: .all,
                                items: [
                                    TradingMarketItem(
                                        id: "ton/mainnet/stocks/0:abcdef",
                                        symbol: "TSLAx",
                                        name: "Tesla",
                                        category: .stocks,
                                        imageURL: nil,
                                        price: nil,
                                        change24hPercent: nil,
                                        verification: .whitelist
                                    ),
                                ]
                            ),
                        ]
                    ),
                ]
            )
        )
        let viewModel = makeViewModel(shelvesService: service)

        viewModel.viewDidAppear()

        await waitUntil {
            await MainActor.run {
                viewModel.shelves.first?.grids.first?.items.first?.preview.assetCategory == .stocks
            }
        }
    }

    @MainActor
    func test_openSeeAll_passesGridInitialCatalogSort() async {
        let expectedSorts: [MultichainAssetSearchSort] = [
            .marketCap,
            .volume,
            .priceDiffDesc,
            .priceDiffAsc,
        ]
        let service = TradingShelvesServiceSpy(
            snapshot: TradingShelvesSnapshot(
                generatedAt: .now,
                currency: .USD,
                shelves: [
                    TradingShelf(
                        id: "shelf",
                        title: "Shelf",
                        grids: expectedSorts.enumerated().map { index, sort in
                            TradingShelfGrid(
                                id: "grid-\(index)",
                                name: "Grid \(index)",
                                source: "api",
                                seeAllCategory: .all,
                                initialCatalogSearchSort: sort,
                                items: [
                                    TradingMarketItem(
                                        id: "ton/mainnet/coin",
                                        symbol: "TON",
                                        name: "Toncoin",
                                        category: .tokens,
                                        imageURL: nil,
                                        price: nil,
                                        change24hPercent: nil,
                                        verification: .whitelist
                                    ),
                                ]
                            )
                        }
                    ),
                ]
            )
        )
        var openedSorts = [MultichainAssetSearchSort]()
        let viewModel = makeViewModel(
            shelvesService: service,
            onOpenAssetList: { _, sort in
                openedSorts.append(sort)
            }
        )

        viewModel.viewDidAppear()

        await waitUntil {
            await MainActor.run {
                viewModel.shelves.first?.grids.count == expectedSorts.count
            }
        }

        for grid in viewModel.shelves[0].grids {
            viewModel.openSeeAll(for: grid)
        }

        XCTAssertEqual(openedSorts, expectedSorts)
    }

    @MainActor
    func test_scrollToGrid_selectsGridAndRequestsParentShelfScrollAfterShelvesLoad() async {
        let service = TradingShelvesServiceSpy(snapshot: makeGridSelectionSnapshot())
        let viewModel = makeViewModel(shelvesService: service)

        viewModel.scrollToGrid(id: "target_grid")
        XCTAssertNil(viewModel.scrollToShelfRequest)

        viewModel.viewDidAppear()

        await waitUntil {
            await MainActor.run {
                viewModel.selectedGridIDs["shelf-2"] == "target_grid"
                    && viewModel.scrollToShelfRequest?.shelfID == "shelf-2"
            }
        }
    }

    @MainActor
    func test_scrollToGrid_repeatsScrollRequestWhenGridAlreadySelected() async {
        let service = TradingShelvesServiceSpy(snapshot: makeGridSelectionSnapshot())
        let viewModel = makeViewModel(shelvesService: service)

        viewModel.viewDidAppear()

        await waitUntil {
            await MainActor.run {
                viewModel.shelves.count == 2
            }
        }

        viewModel.scrollToGrid(id: "target_grid")
        let firstRequest = viewModel.scrollToShelfRequest
        XCTAssertEqual(firstRequest?.shelfID, "shelf-2")
        XCTAssertEqual(viewModel.selectedGridIDs["shelf-2"], "target_grid")

        viewModel.scrollToGrid(id: "target_grid")

        XCTAssertEqual(viewModel.scrollToShelfRequest?.shelfID, "shelf-2")
        XCTAssertEqual(viewModel.scrollToShelfRequest?.id, (firstRequest?.id ?? 0) + 1)
    }

    @MainActor
    func test_viewDidAppear_selectsFirstGroupByDefault() async {
        let service = TradingShelvesServiceSpy(snapshot: makeGroupedSelectionSnapshot())
        let viewModel = makeViewModel(shelvesService: service)

        viewModel.viewDidAppear()

        await waitUntil {
            await MainActor.run {
                viewModel.shelves.count == 1
            }
        }

        let shelf = viewModel.shelves[0]
        XCTAssertEqual(viewModel.selectedGroupID(for: shelf), "ton")
        XCTAssertEqual(viewModel.selectedGroup(for: shelf)?.grids.map(\.id), ["shared_grid", "ton_grid"])
        XCTAssertEqual(viewModel.selectedGridID(for: shelf), "shared_grid")
    }

    @MainActor
    func test_selectGroup_changesVisibleGridsAndItems() async {
        let service = TradingShelvesServiceSpy(snapshot: makeGroupedSelectionSnapshot())
        let viewModel = makeViewModel(shelvesService: service)

        viewModel.viewDidAppear()

        await waitUntil {
            await MainActor.run {
                viewModel.shelves.count == 1
            }
        }

        let shelf = viewModel.shelves[0]
        viewModel.selectGroup(id: "tron", for: shelf)

        XCTAssertEqual(viewModel.selectedGroupID(for: shelf), "tron")
        XCTAssertEqual(viewModel.selectedGroup(for: shelf)?.grids.map(\.id), ["shared_grid", "tron_grid"])
        XCTAssertEqual(viewModel.selectedGroup(for: shelf)?.grids[1].items.first?.symbol, "TRX")
    }

    @MainActor
    func test_selectGroup_preservesSelectedGridWhenAvailable() async {
        let service = TradingShelvesServiceSpy(snapshot: makeGroupedSelectionSnapshot())
        let viewModel = makeViewModel(shelvesService: service)

        viewModel.viewDidAppear()

        await waitUntil {
            await MainActor.run {
                viewModel.shelves.count == 1
            }
        }

        let shelf = viewModel.shelves[0]
        viewModel.selectGrid(id: "shared_grid", for: shelf)
        viewModel.selectGroup(id: "tron", for: shelf)

        XCTAssertEqual(viewModel.selectedGroupID(for: shelf), "tron")
        XCTAssertEqual(viewModel.selectedGridID(for: shelf), "shared_grid")
        XCTAssertEqual(viewModel.selectedGridIDs["shelf-grouped"], "shared_grid")
    }

    @MainActor
    func test_selectGroup_fallsBackToFirstGridWhenSelectedGridIsMissing() async {
        let service = TradingShelvesServiceSpy(snapshot: makeGroupedSelectionSnapshot())
        let viewModel = makeViewModel(shelvesService: service)

        viewModel.viewDidAppear()

        await waitUntil {
            await MainActor.run {
                viewModel.shelves.count == 1
            }
        }

        let shelf = viewModel.shelves[0]
        viewModel.selectGrid(id: "ton_grid", for: shelf)
        viewModel.selectGroup(id: "tron", for: shelf)

        XCTAssertEqual(viewModel.selectedGroupID(for: shelf), "tron")
        XCTAssertEqual(viewModel.selectedGridID(for: shelf), "shared_grid")
        XCTAssertEqual(viewModel.selectedGridIDs["shelf-grouped"], "shared_grid")
    }

    @MainActor
    func test_scrollToGrid_selectsContainingGroupAndRequestsShelfScroll() async {
        let service = TradingShelvesServiceSpy(snapshot: makeGroupedSelectionSnapshot())
        let viewModel = makeViewModel(shelvesService: service)

        viewModel.viewDidAppear()

        await waitUntil {
            await MainActor.run {
                viewModel.shelves.count == 1
            }
        }

        viewModel.scrollToGrid(id: "tron_grid")

        XCTAssertEqual(viewModel.selectedGroupIDs["shelf-grouped"], "tron")
        XCTAssertEqual(viewModel.selectedGridIDs["shelf-grouped"], "tron_grid")
        XCTAssertEqual(viewModel.scrollToShelfRequest?.shelfID, "shelf-grouped")
    }

    @MainActor
    func test_scrollToGrid_picksFirstGroupForGridSharedAcrossGroups() async {
        let service = TradingShelvesServiceSpy(snapshot: makeGroupedSelectionSnapshot())
        let viewModel = makeViewModel(shelvesService: service)

        viewModel.viewDidAppear()

        await waitUntil {
            await MainActor.run {
                viewModel.shelves.count == 1
            }
        }

        // "shared_grid" exists in both the TON and TRON groups; an ambiguous
        // deeplink must resolve to the first matching group, not a later chain.
        viewModel.scrollToGrid(id: "shared_grid")

        XCTAssertEqual(viewModel.selectedGroupIDs["shelf-grouped"], "ton")
        XCTAssertEqual(viewModel.selectedGridIDs["shelf-grouped"], "shared_grid")
        XCTAssertEqual(viewModel.scrollToShelfRequest?.shelfID, "shelf-grouped")
    }

    @MainActor
    func test_scrollToGrid_picksFirstGroupForPendingGridSharedAcrossGroups() async {
        let service = TradingShelvesServiceSpy(snapshot: makeGroupedSelectionSnapshot())
        let viewModel = makeViewModel(shelvesService: service)

        // Deeplink arrives before shelves load: the gridID is buffered and
        // must still resolve to the first matching group once shelves apply.
        viewModel.scrollToGrid(id: "shared_grid")
        XCTAssertNil(viewModel.scrollToShelfRequest)

        viewModel.viewDidAppear()

        await waitUntil {
            await MainActor.run {
                viewModel.selectedGroupIDs["shelf-grouped"] == "ton"
                    && viewModel.selectedGridIDs["shelf-grouped"] == "shared_grid"
                    && viewModel.scrollToShelfRequest?.shelfID == "shelf-grouped"
            }
        }
    }

    @MainActor
    func test_viewDidAppear_loadsFavoriteAssetsBeforePriceDiffs() async {
        let marketItemsGate = TestGate()
        let favoriteAssetsService = FavoriteAssetsServiceSpy(
            assets: [
                makeFavoriteAsset(id: "ton/mainnet/jetton/0:123", symbol: "JET"),
            ],
            marketItemsGate: marketItemsGate
        )
        let viewModel = makeViewModel(
            shelvesService: TradingShelvesServiceSpy(snapshot: makeEmptySnapshot()),
            favoriteAssetsService: favoriteAssetsService
        )

        viewModel.viewDidAppear()

        // Market items fetch is suspended at the gate, so the favorite is
        // deterministically observable in its pre-price-diff (shimmer) state.
        await marketItemsGate.waitUntilEntered()

        XCTAssertEqual(viewModel.favoriteAssets.first?.symbol, "JET")
        XCTAssertEqual(viewModel.favoriteAssets.first?.isChangeLoading, true)
        XCTAssertNil(viewModel.favoriteAssets.first?.changeText)

        await marketItemsGate.open()
    }

    @MainActor
    func test_viewDidAppear_updatesFavoritesPriceDiffs() async throws {
        let priceDiff = try XCTUnwrap(Decimal(string: "-1.25"))
        let favoriteAssetsService = FavoriteAssetsServiceSpy(
            assets: [
                makeFavoriteAsset(id: "ton/mainnet/jetton/0:123", symbol: "JET"),
            ],
            marketItems: [
                "ton/mainnet/jetton/0:123": TradingMarketItem(
                    id: "ton/mainnet/jetton/0:123",
                    symbol: "JET",
                    name: "Jetton",
                    category: .tokens,
                    imageURL: nil,
                    price: nil,
                    change24hPercent: priceDiff,
                    verification: .whitelist
                ),
            ]
        )
        let expectedChangeText = FormattersAssembly().signedAmountFormatter.format(
            decimal: priceDiff,
            style: .percent
        )
        let viewModel = makeViewModel(
            shelvesService: TradingShelvesServiceSpy(snapshot: makeEmptySnapshot()),
            favoriteAssetsService: favoriteAssetsService
        )

        viewModel.viewDidAppear()

        await waitUntil {
            await MainActor.run {
                viewModel.favoriteAssets.first?.changeText == expectedChangeText
                    && viewModel.favoriteAssets.first?.isChangeLoading == false
            }
        }
    }

    @MainActor
    func test_viewDidAppear_allFavoritesShimmerUntilPriceDiffsLoad() async {
        // A cached value must NOT short-circuit the shimmer: every favorite's
        // 24h price-diff shimmers until the fresh market-items batch returns,
        // matching the loading behaviour of the other tab items.
        let cachedItem = makeMarketItem(
            id: "ton/mainnet/jetton/0:123",
            symbol: "JET",
            category: .tokens,
            change: "2.0"
        )
        let marketItemsGate = TestGate()
        let favoriteAssetsService = FavoriteAssetsServiceSpy(
            assets: [
                makeFavoriteAsset(id: "ton/mainnet/jetton/0:123", symbol: "JET"),
                makeFavoriteAsset(id: "ton/mainnet/jetton/0:456", symbol: "FOO"),
            ],
            marketItems: [
                "ton/mainnet/jetton/0:123": cachedItem,
                "ton/mainnet/jetton/0:456": makeMarketItem(
                    id: "ton/mainnet/jetton/0:456",
                    symbol: "FOO",
                    category: .tokens,
                    change: "3.0"
                ),
            ],
            cachedMarketItems: ["ton/mainnet/jetton/0:123": cachedItem],
            marketItemsGate: marketItemsGate
        )
        let viewModel = makeViewModel(
            shelvesService: TradingShelvesServiceSpy(snapshot: makeEmptySnapshot()),
            favoriteAssetsService: favoriteAssetsService
        )

        viewModel.viewDidAppear()

        // Fetch suspended at the gate: both favorites shimmer, including the
        // one that already has a cached value.
        await marketItemsGate.waitUntilEntered()
        XCTAssertEqual(viewModel.favoriteAssets.count, 2)
        XCTAssertTrue(viewModel.favoriteAssets.allSatisfy { $0.isChangeLoading })
        XCTAssertTrue(viewModel.favoriteAssets.allSatisfy { $0.changeText == nil })

        await marketItemsGate.open()

        await waitUntil {
            await MainActor.run {
                viewModel.favoriteAssets.allSatisfy {
                    !$0.isChangeLoading && $0.changeText != nil
                }
            }
        }
    }

    @MainActor
    func test_refresh_usesForceRefreshWhileColdStartDoesNot() async {
        let favoriteAssetsService = FavoriteAssetsServiceSpy(
            assets: [makeFavoriteAsset(id: "ton/mainnet/jetton/0:123", symbol: "JET")]
        )
        let viewModel = makeViewModel(
            shelvesService: TradingShelvesServiceSpy(snapshot: makeEmptySnapshot()),
            favoriteAssetsService: favoriteAssetsService
        )

        viewModel.viewDidAppear()
        await waitUntil {
            let flags = await favoriteAssetsService.marketItemsForceRefreshFlags
            return flags.count >= 1
        }
        var flags = await favoriteAssetsService.marketItemsForceRefreshFlags
        XCTAssertEqual(flags.last, false)

        await viewModel.refresh()
        await waitUntil {
            let flags = await favoriteAssetsService.marketItemsForceRefreshFlags
            return flags.count >= 2
        }
        flags = await favoriteAssetsService.marketItemsForceRefreshFlags
        XCTAssertEqual(flags.last, true)

        viewModel.refreshFavoriteAssets()
        await waitUntil {
            let flags = await favoriteAssetsService.marketItemsForceRefreshFlags
            return flags.count >= 3
        }
        flags = await favoriteAssetsService.marketItemsForceRefreshFlags
        XCTAssertEqual(flags.last, true)
    }

    @MainActor
    func test_refreshInFlight_transitionsFromPendingToRefreshingToLoaded() async {
        let loadShelvesGate = TestGate()
        let favoriteAssetsService = FavoriteAssetsServiceSpy(
            assets: [makeFavoriteAsset(id: "ton/mainnet/jetton/0:123", symbol: "JET")]
        )
        let shelvesService = TradingShelvesServiceSpy(
            snapshot: makeEmptySnapshot(),
            loadShelvesGate: loadShelvesGate
        )
        let viewModel = makeViewModel(
            shelvesService: shelvesService,
            favoriteAssetsService: favoriteAssetsService
        )

        guard case let .pending(initialData) = viewModel.state else {
            return XCTFail("Expected pending shelves state")
        }
        XCTAssertTrue(initialData.shelves.isEmpty)

        let refreshTask = Task { await viewModel.refresh() }

        // Refresh is suspended inside loadShelves, so the refreshing state is stable.
        await loadShelvesGate.waitUntilEntered()
        guard case let .refreshing(data, task: _) = viewModel.state else {
            return XCTFail("Expected refreshing shelves state")
        }
        XCTAssertTrue(data.shelves.isEmpty)

        await loadShelvesGate.open()
        await refreshTask.value

        guard case .loaded = viewModel.state else {
            return XCTFail("Expected loaded shelves state")
        }
    }

    @MainActor
    func test_cachedShelves_areAppliedWhileRefreshIsInFlight() async {
        let loadShelvesGate = TestGate()
        let viewModel = makeViewModel(
            shelvesService: TradingShelvesServiceSpy(
                snapshot: makeSnapshot(title: "Cached"),
                loadShelvesGate: loadShelvesGate
            )
        )

        viewModel.viewDidAppear()
        await loadShelvesGate.waitUntilEntered()

        guard case let .refreshing(data, task: _) = viewModel.state else {
            return XCTFail("Expected refreshing shelves state")
        }
        XCTAssertEqual(data.shelves.first?.title, "Cached")

        await loadShelvesGate.open()
        await waitUntil {
            await MainActor.run {
                if case .loaded = viewModel.state {
                    return true
                }
                return false
            }
        }
    }

    @MainActor
    func test_failedRefresh_preservesCachedShelvesAsFallback() async {
        let viewModel = makeViewModel(
            shelvesService: TradingShelvesServiceSpy(
                snapshot: makeSnapshot(title: "Cached"),
                loadFailure: .apiError(message: nil)
            )
        )

        viewModel.viewDidAppear()
        await waitUntil {
            await MainActor.run {
                if case .failed = viewModel.state {
                    return true
                }
                return false
            }
        }

        guard case let .failed(data) = viewModel.state else {
            return XCTFail("Expected failed shelves state")
        }
        XCTAssertEqual(data.shelves.first?.title, "Cached")
    }

    @MainActor
    func test_refreshWhileRefreshing_waitsForExistingTask() async {
        let loadShelvesGate = TestGate()
        let service = ModeTradingShelvesServiceSpy(
            snapshots: [.multichain: makeEmptySnapshot()],
            loadGates: [.multichain: loadShelvesGate]
        )
        let viewModel = makeViewModel(shelvesService: service)

        viewModel.viewDidAppear()
        await loadShelvesGate.waitUntilEntered()

        let refreshTask = Task { await viewModel.refresh() }
        let callsBeforeRelease = await service.loadCalls
        XCTAssertEqual(callsBeforeRelease, [.multichain])

        await loadShelvesGate.open()
        await refreshTask.value

        let calls = await service.loadCalls
        XCTAssertEqual(calls, [.multichain])
    }

    @MainActor
    func test_refreshFavoriteAssets_whenLoaded_refetches() async {
        let item = makeMarketItem(
            id: "ton/mainnet/jetton/0:123",
            symbol: "JET",
            category: .tokens,
            change: "1.5"
        )
        let favoriteAssetsService = FavoriteAssetsServiceSpy(
            assets: [makeFavoriteAsset(id: "ton/mainnet/jetton/0:123", symbol: "JET")],
            marketItems: ["ton/mainnet/jetton/0:123": item]
        )
        let viewModel = makeViewModel(
            shelvesService: TradingShelvesServiceSpy(snapshot: makeEmptySnapshot()),
            favoriteAssetsService: favoriteAssetsService
        )

        viewModel.viewDidAppear()
        await waitUntil {
            await MainActor.run {
                if case .loaded = viewModel.state {
                    return true
                }
                return false
            }
        }
        let fetchesAfterLoad = await favoriteAssetsService.marketItemsAssetIDs.count

        // The initial pending state was resolved, so the guard lets the refresh through.
        viewModel.refreshFavoriteAssets()

        await waitUntil {
            await favoriteAssetsService.marketItemsAssetIDs.count == fetchesAfterLoad + 1
        }
    }

    @MainActor
    func test_applyMarketItems_stopsShimmerForAssetsMissingFromResponse() async {
        let fetchedItem = makeMarketItem(
            id: "ton/mainnet/jetton/0:123",
            symbol: "JET",
            category: .tokens,
            change: "3.0"
        )
        let favoriteAssetsService = FavoriteAssetsServiceSpy(
            assets: [
                makeFavoriteAsset(id: "ton/mainnet/jetton/0:123", symbol: "JET"),
                makeFavoriteAsset(id: "ton/mainnet/jetton/0:456", symbol: "FOO"),
            ],
            marketItems: ["ton/mainnet/jetton/0:123": fetchedItem]
        )
        let viewModel = makeViewModel(
            shelvesService: TradingShelvesServiceSpy(snapshot: makeEmptySnapshot()),
            favoriteAssetsService: favoriteAssetsService
        )

        viewModel.viewDidAppear()

        await waitUntil {
            await MainActor.run {
                guard viewModel.favoriteAssets.count == 2 else { return false }
                return viewModel.favoriteAssets[0].isChangeLoading == false
                    && viewModel.favoriteAssets[1].isChangeLoading == false
            }
        }

        XCTAssertNotNil(viewModel.favoriteAssets[0].changeText)
        XCTAssertEqual(viewModel.favoriteAssets[1].symbol, "FOO")
    }

    @MainActor
    func test_overlappingAsset_changeStaysInSyncBetweenShelvesAndFavorites() async throws {
        let sharedID = "ton/mainnet/coin"
        let staleShelfChange = try XCTUnwrap(Decimal(string: "-1.0"))
        let settledItem = makeMarketItem(
            id: sharedID,
            symbol: "TON",
            category: .tokens,
            change: "2.0"
        )
        let settledChange = try XCTUnwrap(settledItem.change24hPercent)

        // Shelf snapshot carries a different (stale) change than the shared cache.
        let shelvesService = TradingShelvesServiceSpy(
            snapshot: TradingShelvesSnapshot(
                generatedAt: .now,
                currency: .USD,
                shelves: [
                    TradingShelf(
                        id: "shelf",
                        title: "Shelf",
                        grids: [
                            TradingShelfGrid(
                                id: "grid",
                                name: "Grid",
                                source: "api",
                                seeAllCategory: .all,
                                items: [
                                    TradingMarketItem(
                                        id: sharedID,
                                        symbol: "TON",
                                        name: "Toncoin",
                                        category: .tokens,
                                        imageURL: nil,
                                        price: nil,
                                        change24hPercent: staleShelfChange,
                                        verification: .whitelist
                                    ),
                                ]
                            ),
                        ]
                    ),
                ]
            )
        )
        let favoriteAssetsService = FavoriteAssetsServiceSpy(
            assets: [makeFavoriteAsset(id: sharedID, symbol: "TON")],
            marketItems: [sharedID: settledItem],
            cachedMarketItems: [sharedID: settledItem]
        )
        let viewModel = makeViewModel(
            shelvesService: shelvesService,
            favoriteAssetsService: favoriteAssetsService
        )

        viewModel.viewDidAppear()

        await waitUntil {
            await MainActor.run {
                let shelfItem = viewModel.shelves.first?.grids.first?.items.first
                let favoriteItem = viewModel.favoriteAssets.first
                return shelfItem?.preview.change24hPercent == settledChange
                    && favoriteItem?.preview.change24hPercent == settledChange
            }
        }

        let shelfItem = try XCTUnwrap(viewModel.shelves.first?.grids.first?.items.first)
        let favoriteItem = try XCTUnwrap(viewModel.favoriteAssets.first)
        XCTAssertEqual(shelfItem.preview.change24hPercent, favoriteItem.preview.change24hPercent)
        XCTAssertNotEqual(shelfItem.preview.change24hPercent, staleShelfChange)
        XCTAssertEqual(shelfItem.changeText, favoriteItem.changeText)
        XCTAssertEqual(shelfItem.changeColor, favoriteItem.changeColor)
    }

    func test_shelvesMapper_mapsSnapshotAndAppliesMarketItemChanges() throws {
        let change = try XCTUnwrap(Decimal(string: "2.0"))
        let itemsMapper = TradeItemsMapper(
            multichainEnabled: true,
            signedAmountFormatter: FormattersAssembly().signedAmountFormatter
        )
        let mappedShelves = TradeShelvesMapper.makeShelves(
            from: makeGridSelectionSnapshot(),
            itemsMapper: itemsMapper
        )
        let shelves = TradeShelvesMapper.applyingMarketItems(
            [
                "ton/mainnet/coin": makeMarketItem(
                    id: "ton/mainnet/coin",
                    symbol: "TON",
                    category: .tokens,
                    change: "2.0"
                ),
            ],
            to: mappedShelves,
            itemsMapper: itemsMapper
        )

        let item = try XCTUnwrap(shelves.first?.grids.first?.items.first)
        XCTAssertEqual(item.preview.change24hPercent, change)
        XCTAssertFalse(item.isChangeLoading)
    }

    @MainActor
    func test_refreshFavoriteAssets_beforeLoad_doesNothing() async {
        let favoriteAssetsService = FavoriteAssetsServiceSpy(
            assets: [makeFavoriteAsset(id: "ton/mainnet/jetton/0:123", symbol: "JET")]
        )
        let viewModel = makeViewModel(
            shelvesService: TradingShelvesServiceSpy(snapshot: makeEmptySnapshot()),
            favoriteAssetsService: favoriteAssetsService
        )

        // The initial state is pending, so the guard rejects synchronously and never
        // launches a fetch task -- the assertions hold without any waiting.
        viewModel.refreshFavoriteAssets()

        XCTAssertTrue(viewModel.favoriteAssets.isEmpty)
        let requestedIDs = await favoriteAssetsService.marketItemsAssetIDs
        XCTAssertTrue(requestedIDs.isEmpty)
    }

    @MainActor
    func test_openFavoriteAsset_opensPreviewContext() async {
        let favoriteAssetsService = FavoriteAssetsServiceSpy(
            assets: [
                makeFavoriteAsset(id: "ton/mainnet/jetton/0:123", symbol: "JET"),
            ]
        )
        var openedPreview: TradeAssetDetailsViewModel.PreviewContext?
        let viewModel = makeViewModel(
            shelvesService: TradingShelvesServiceSpy(snapshot: makeEmptySnapshot()),
            favoriteAssetsService: favoriteAssetsService,
            onOpenAssetDetails: { openedPreview = $0 }
        )

        viewModel.viewDidAppear()

        await waitUntil {
            await MainActor.run {
                !viewModel.favoriteAssets.isEmpty
            }
        }

        viewModel.openAsset(viewModel.favoriteAssets[0])

        XCTAssertEqual(openedPreview?.assetID, "ton/mainnet/jetton/0:123")
        XCTAssertEqual(openedPreview?.symbol, "JET")
        XCTAssertNil(openedPreview?.assetCategory)
    }

    func test_multichainPreviewContext_usesAssetVerificationState() {
        let verifiedPreview = TradeItemsMapper.previewContext(
            for: makeMultichainAsset(id: "eth/mainnet/coin", verification: .whitelist)
        )
        let unverifiedPreview = TradeItemsMapper.previewContext(
            for: makeMultichainAsset(id: "eth/mainnet/erc20/0x123", verification: .none)
        )
        let scamPreview = TradeItemsMapper.previewContext(
            for: makeMultichainAsset(id: "eth/mainnet/erc20/0xscam", verification: .blacklist)
        )

        XCTAssertEqual(verifiedPreview.isUnverified, false)
        XCTAssertEqual(unverifiedPreview.isUnverified, true)
        XCTAssertEqual(scamPreview.isUnverified, true)
    }

    @MainActor
    func test_toggleFavoritesEditing_togglesEditingState() {
        let viewModel = makeViewModel(
            shelvesService: TradingShelvesServiceSpy(snapshot: makeEmptySnapshot())
        )

        XCTAssertFalse(viewModel.isFavoritesEditing)

        viewModel.toggleFavoritesEditing()
        XCTAssertTrue(viewModel.isFavoritesEditing)

        viewModel.toggleFavoritesEditing()
        XCTAssertFalse(viewModel.isFavoritesEditing)
    }

    @MainActor
    func test_removeFavorite_defersRemovalUntilDone() async {
        let favoriteAssetsService = FavoriteAssetsServiceSpy(
            assets: [
                makeFavoriteAsset(id: "ton/mainnet/jetton/0:123", symbol: "JET"),
                makeFavoriteAsset(id: "ton/mainnet/jetton/0:456", symbol: "FOO"),
            ]
        )
        let viewModel = makeViewModel(
            shelvesService: TradingShelvesServiceSpy(snapshot: makeEmptySnapshot()),
            favoriteAssetsService: favoriteAssetsService
        )

        viewModel.viewDidAppear()

        await waitUntil {
            await MainActor.run {
                viewModel.favoriteAssets.count == 2
            }
        }

        viewModel.toggleFavoritesEditing()
        let removed = viewModel.favoriteAssets[0]
        viewModel.removeFavorite(removed)

        // Crossed out: hidden from the section, but not yet removed or persisted.
        XCTAssertFalse(viewModel.visibleFavoriteAssets.contains { $0.id == removed.id })
        XCTAssertTrue(viewModel.favoriteAssets.contains { $0.id == removed.id })
        let callsBeforeDone = await favoriteAssetsService.favoriteContexts
        XCTAssertFalse(callsBeforeDone.contains { $0.context.id == removed.id })

        // Done commits the removal.
        viewModel.toggleFavoritesEditing()
        XCTAssertFalse(viewModel.isFavoritesEditing)
        XCTAssertFalse(viewModel.favoriteAssets.contains { $0.id == removed.id })

        await waitUntil {
            let calls = await favoriteAssetsService.favoriteContexts
            return calls.contains { !$0.isFavorite && $0.context.id == removed.id }
        }
    }

    @MainActor
    func test_exitFavoritesEditing_discardsPendingRemovals() async {
        let favoriteAssetsService = FavoriteAssetsServiceSpy(
            assets: [
                makeFavoriteAsset(id: "ton/mainnet/jetton/0:123", symbol: "JET"),
                makeFavoriteAsset(id: "ton/mainnet/jetton/0:456", symbol: "FOO"),
            ]
        )
        let viewModel = makeViewModel(
            shelvesService: TradingShelvesServiceSpy(snapshot: makeEmptySnapshot()),
            favoriteAssetsService: favoriteAssetsService
        )

        viewModel.viewDidAppear()

        await waitUntil {
            await MainActor.run {
                viewModel.favoriteAssets.count == 2
            }
        }

        viewModel.toggleFavoritesEditing()
        let removed = viewModel.favoriteAssets[0]
        viewModel.removeFavorite(removed)
        XCTAssertEqual(viewModel.visibleFavoriteAssets.count, 1)

        // Navigating away (exit edit) restores the crossed-out item, persists nothing.
        viewModel.exitFavoritesEditing()
        XCTAssertFalse(viewModel.isFavoritesEditing)
        XCTAssertEqual(viewModel.visibleFavoriteAssets.count, 2)
        XCTAssertTrue(viewModel.visibleFavoriteAssets.contains { $0.id == removed.id })

        let calls = await favoriteAssetsService.favoriteContexts
        XCTAssertFalse(calls.contains { $0.context.id == removed.id })
    }

    @MainActor
    func test_removeLastFavorite_keepsEditingUntilDone() async {
        let favoriteAssetsService = FavoriteAssetsServiceSpy(
            assets: [
                makeFavoriteAsset(id: "ton/mainnet/jetton/0:123", symbol: "JET"),
            ]
        )
        let viewModel = makeViewModel(
            shelvesService: TradingShelvesServiceSpy(snapshot: makeEmptySnapshot()),
            favoriteAssetsService: favoriteAssetsService
        )

        viewModel.viewDidAppear()

        await waitUntil {
            await MainActor.run {
                viewModel.favoriteAssets.count == 1
            }
        }

        viewModel.toggleFavoritesEditing()
        XCTAssertTrue(viewModel.isFavoritesEditing)

        let removed = viewModel.favoriteAssets[0]
        viewModel.removeFavorite(removed)

        // Crossing out the last item leaves the section in edit mode so Done stays reachable.
        XCTAssertTrue(viewModel.visibleFavoriteAssets.isEmpty)
        XCTAssertFalse(viewModel.favoriteAssets.isEmpty)
        XCTAssertTrue(viewModel.isFavoritesEditing)

        viewModel.toggleFavoritesEditing()
        XCTAssertFalse(viewModel.isFavoritesEditing)
        XCTAssertTrue(viewModel.favoriteAssets.isEmpty)

        await waitUntil {
            let calls = await favoriteAssetsService.favoriteContexts
            return calls.contains { !$0.isFavorite && $0.context.id == removed.id }
        }
    }

    @MainActor
    func test_activeWalletChangeWhileVisible_appliesModeCacheAndRefreshesIt() async {
        let legacyWallet = makeWallet(id: "legacy")
        let multichainWallet = makeWallet(
            id: "multichain",
            multichain: .multichain(
                .init(
                    walletId: "multichain",
                    addresses: [MultichainWalletAddress(chain: .eth, address: "0xmultichain")]
                )
            )
        )
        let walletsStore = makeWalletsStore(wallets: [legacyWallet, multichainWallet])
        let service = ModeTradingShelvesServiceSpy(
            snapshots: [
                .legacy: makeSnapshot(title: "Legacy"),
                .multichain: makeSnapshot(title: "Multichain"),
            ]
        )
        let viewModel = makeViewModel(
            shelvesService: service,
            walletsStore: walletsStore
        )

        viewModel.viewDidAppear()
        await waitUntil {
            await MainActor.run {
                viewModel.shelves.first?.title == "Legacy"
            }
        }

        _ = await walletsStore.makeWalletActive(multichainWallet)

        await waitUntil {
            let calls = await service.loadCalls
            return await MainActor.run {
                viewModel.shelves.first?.title == "Multichain"
                    && calls.contains(.multichain)
            }
        }

        let calls = await service.loadCalls
        XCTAssertEqual(calls, [.legacy, .multichain])
    }

    @MainActor
    func test_activeWalletChangeWhileHidden_defersRefreshUntilTradeAppears() async {
        let legacyWallet = makeWallet(id: "legacy")
        let multichainWallet = makeWallet(
            id: "multichain",
            multichain: .multichain(
                .init(
                    walletId: "multichain",
                    addresses: [MultichainWalletAddress(chain: .eth, address: "0xmultichain")]
                )
            )
        )
        let walletsStore = makeWalletsStore(wallets: [legacyWallet, multichainWallet])
        let service = ModeTradingShelvesServiceSpy(
            snapshots: [
                .legacy: makeSnapshot(title: "Legacy"),
                .multichain: makeSnapshot(title: "Multichain"),
            ]
        )
        let viewModel = makeViewModel(
            shelvesService: service,
            walletsStore: walletsStore
        )

        _ = await walletsStore.makeWalletActive(multichainWallet)
        _ = await walletsStore.makeWalletActive(legacyWallet)
        await waitUntil {
            await MainActor.run {
                !viewModel.multichainEnabled
            }
        }

        let callsBeforeAppear = await service.loadCalls
        XCTAssertTrue(callsBeforeAppear.isEmpty)
        guard case let .pending(data) = viewModel.state else {
            return XCTFail("Expected pending shelves state while Trade is hidden")
        }
        XCTAssertEqual(data.mode, .legacy)

        viewModel.viewDidAppear()
        await waitUntil {
            let calls = await service.loadCalls
            return await MainActor.run {
                viewModel.shelves.first?.title == "Legacy"
                    && calls == [.legacy]
            }
        }
    }

    @MainActor
    func test_lateResponseForPreviousMode_doesNotReplaceCurrentShelves() async {
        let legacyWallet = makeWallet(id: "legacy")
        let multichainWallet = makeWallet(
            id: "multichain",
            multichain: .multichain(
                .init(
                    walletId: "multichain",
                    addresses: [MultichainWalletAddress(chain: .eth, address: "0xmultichain")]
                )
            )
        )
        let legacyLoadGate = TestGate()
        let walletsStore = makeWalletsStore(wallets: [legacyWallet, multichainWallet])
        let service = ModeTradingShelvesServiceSpy(
            snapshots: [
                .legacy: makeSnapshot(title: "Legacy"),
                .multichain: makeSnapshot(title: "Multichain"),
            ],
            loadGates: [.legacy: legacyLoadGate]
        )
        let viewModel = makeViewModel(
            shelvesService: service,
            walletsStore: walletsStore
        )

        viewModel.viewDidAppear()
        await legacyLoadGate.waitUntilEntered()

        _ = await walletsStore.makeWalletActive(multichainWallet)
        await waitUntil {
            await MainActor.run {
                viewModel.shelves.first?.title == "Multichain"
            }
        }

        await legacyLoadGate.open()
        await waitUntil {
            let calls = await service.loadCalls
            return calls == [.legacy, .multichain]
        }

        XCTAssertEqual(viewModel.shelves.first?.title, "Multichain")
    }

    @MainActor
    func test_activeWalletChangeWithSameMode_doesNotRefetchShelves() async {
        let multichainWalletA = makeWallet(
            id: "multichain-a",
            multichain: .multichain(
                .init(
                    walletId: "multichain-a",
                    addresses: [MultichainWalletAddress(chain: .eth, address: "0xa")]
                )
            )
        )
        let multichainWalletB = makeWallet(
            id: "multichain-b",
            multichain: .multichain(
                .init(
                    walletId: "multichain-b",
                    addresses: [MultichainWalletAddress(chain: .eth, address: "0xb")]
                )
            )
        )
        let legacyWallet = makeWallet(id: "legacy")
        let walletsStore = makeWalletsStore(
            wallets: [multichainWalletA, multichainWalletB, legacyWallet]
        )
        let service = ModeTradingShelvesServiceSpy(
            snapshots: [
                .legacy: makeSnapshot(title: "Legacy"),
                .multichain: makeSnapshot(title: "Multichain"),
            ]
        )
        let viewModel = makeViewModel(
            shelvesService: service,
            walletsStore: walletsStore
        )

        viewModel.viewDidAppear()
        await waitUntil {
            await MainActor.run {
                viewModel.shelves.first?.title == "Multichain"
            }
        }

        _ = await walletsStore.makeWalletActive(multichainWalletB)
        // A same-mode refetch would insert an extra .multichain call before .legacy.
        _ = await walletsStore.makeWalletActive(legacyWallet)
        await waitUntil {
            let calls = await service.loadCalls
            return calls == [.multichain, .legacy]
        }

        XCTAssertEqual(viewModel.shelves.first?.title, "Legacy")
    }

    @MainActor
    func test_perpsShelf_prefetchesEightMarketsAndOpensSelectedMarket() async {
        let snapshots = (1 ... 9).map {
            makePerpsMarket(marketID: Int64($0), symbol: "MARKET\($0)")
        }
        var openedMarketID: Int64?
        let viewModel = makeViewModel(
            shelvesService: TradingShelvesServiceSpy(snapshot: makeEmptySnapshot()),
            perpsShelfMarketsLoader: { snapshots },
            onOpenPerps: {},
            onOpenPerpsMarket: { openedMarketID = $0 }
        )

        await waitUntil {
            await MainActor.run {
                viewModel.perpsShelfMarkets.count == 8
            }
        }

        XCTAssertEqual(viewModel.perpsShelfMarkets.map(\.id), Array(1 ... 8).map(Int64.init))

        viewModel.openPerpsMarket(viewModel.perpsShelfMarkets[3].id)

        XCTAssertEqual(openedMarketID, 4)
    }

    @MainActor
    func test_perpsShelf_reloadsWhenActiveWalletChanges() async {
        let walletA = makeWallet(
            id: "wallet-a",
            multichain: .multichain(
                .init(
                    walletId: "wallet-a",
                    addresses: [MultichainWalletAddress(chain: .eth, address: "0xa")]
                )
            )
        )
        let walletB = makeWallet(
            id: "wallet-b",
            multichain: .multichain(
                .init(
                    walletId: "wallet-b",
                    addresses: [MultichainWalletAddress(chain: .eth, address: "0xb")]
                )
            )
        )
        let walletsStore = makeWalletsStore(wallets: [walletA, walletB])
        var loadCount = 0
        let viewModel = makeViewModel(
            shelvesService: TradingShelvesServiceSpy(snapshot: makeEmptySnapshot()),
            walletsStore: walletsStore,
            perpsShelfMarketsLoader: {
                loadCount += 1
                return [self.makePerpsMarket(marketID: Int64(loadCount), symbol: "MARKET\(loadCount)")]
            },
            onOpenPerps: {},
            onOpenPerpsMarket: { _ in }
        )

        await waitUntil {
            await MainActor.run { viewModel.perpsShelfMarkets.first?.id == 1 }
        }

        _ = await walletsStore.makeWalletActive(walletB)

        await waitUntil {
            await MainActor.run { viewModel.perpsShelfMarkets.first?.id == 2 }
        }
        XCTAssertEqual(loadCount, 2)
    }

    @MainActor
    func test_perpsShelf_ignoresCompletionFromPreviousWallet() async {
        let walletA = makeWallet(
            id: "wallet-a",
            multichain: .multichain(
                .init(
                    walletId: "wallet-a",
                    addresses: [MultichainWalletAddress(chain: .eth, address: "0xa")]
                )
            )
        )
        let walletB = makeWallet(
            id: "wallet-b",
            multichain: .multichain(
                .init(
                    walletId: "wallet-b",
                    addresses: [MultichainWalletAddress(chain: .eth, address: "0xb")]
                )
            )
        )
        let firstLoadGate = TestGate()
        let secondLoadGate = TestGate()
        let walletsStore = makeWalletsStore(wallets: [walletA, walletB])
        var loadCount = 0
        let viewModel = makeViewModel(
            shelvesService: TradingShelvesServiceSpy(snapshot: makeEmptySnapshot()),
            walletsStore: walletsStore,
            perpsShelfMarketsLoader: {
                loadCount += 1
                let currentLoad = loadCount
                if currentLoad == 1 {
                    await firstLoadGate.enter()
                } else {
                    await secondLoadGate.enter()
                }
                return [self.makePerpsMarket(marketID: Int64(currentLoad), symbol: "MARKET\(currentLoad)")]
            },
            onOpenPerps: {},
            onOpenPerpsMarket: { _ in }
        )
        await firstLoadGate.waitUntilEntered()

        _ = await walletsStore.makeWalletActive(walletB)
        await secondLoadGate.waitUntilEntered()
        await secondLoadGate.open()
        await waitUntil {
            await MainActor.run { viewModel.perpsShelfMarkets.first?.id == 2 }
        }

        await firstLoadGate.open()
        await Task.yield()

        XCTAssertEqual(viewModel.perpsShelfMarkets.first?.id, 2)
    }

    @MainActor
    func test_perpsShelf_featureDisabled_doesNotLoadOrOpen() async {
        var loadCount = 0
        var openedMarketID: Int64?
        let viewModel = makeViewModel(
            shelvesService: TradingShelvesServiceSpy(snapshot: makeEmptySnapshot()),
            perpsShelfMarketsLoader: {
                loadCount += 1
                return [self.makePerpsMarket(marketID: 1, symbol: "BTC")]
            },
            onOpenPerps: nil,
            onOpenPerpsMarket: { openedMarketID = $0 }
        )

        await Task.yield()
        viewModel.openPerpsMarket(1)

        XCTAssertEqual(loadCount, 0)
        XCTAssertNil(openedMarketID)
        XCTAssertTrue(viewModel.perpsShelfMarkets.isEmpty)
    }

    @MainActor
    func test_perpsShelf_refreshFailureKeepsCurrentMarkets() async {
        var loadCount = 0
        let viewModel = makeViewModel(
            shelvesService: TradingShelvesServiceSpy(snapshot: makeEmptySnapshot()),
            perpsShelfMarketsLoader: {
                loadCount += 1
                if loadCount > 1 {
                    throw PerpsShelfTestError.failed
                }
                return [self.makePerpsMarket(marketID: 1, symbol: "BTC")]
            },
            onOpenPerps: {},
            onOpenPerpsMarket: { _ in }
        )
        await waitUntil {
            await MainActor.run { viewModel.perpsShelfMarkets.first?.id == 1 }
        }

        await viewModel.refresh()

        XCTAssertEqual(loadCount, 2)
        XCTAssertEqual(viewModel.perpsShelfMarkets.first?.id, 1)
    }

    @MainActor
    func test_perpsShelf_walletSwitchLoadFailureKeepsCurrentMarkets() async {
        let walletA = makeWallet(
            id: "wallet-a",
            multichain: .multichain(
                .init(
                    walletId: "wallet-a",
                    addresses: [MultichainWalletAddress(chain: .eth, address: "0xa")]
                )
            )
        )
        let walletB = makeWallet(
            id: "wallet-b",
            multichain: .multichain(
                .init(
                    walletId: "wallet-b",
                    addresses: [MultichainWalletAddress(chain: .eth, address: "0xb")]
                )
            )
        )
        let secondLoadGate = TestGate()
        let walletsStore = makeWalletsStore(wallets: [walletA, walletB])
        var loadCount = 0
        let viewModel = makeViewModel(
            shelvesService: TradingShelvesServiceSpy(snapshot: makeEmptySnapshot()),
            walletsStore: walletsStore,
            perpsShelfMarketsLoader: {
                loadCount += 1
                if loadCount == 1 {
                    return [self.makePerpsMarket(marketID: 1, symbol: "BTC")]
                }
                await secondLoadGate.enter()
                throw PerpsShelfTestError.failed
            },
            onOpenPerps: {},
            onOpenPerpsMarket: { _ in }
        )
        await waitUntil {
            await MainActor.run { viewModel.perpsShelfMarkets.first?.id == 1 }
        }

        _ = await walletsStore.makeWalletActive(walletB)
        await secondLoadGate.waitUntilEntered()
        XCTAssertEqual(viewModel.perpsShelfMarkets.first?.id, 1)

        await secondLoadGate.open()
        await Task.yield()

        XCTAssertEqual(loadCount, 2)
        XCTAssertEqual(viewModel.perpsShelfMarkets.first?.id, 1)
    }

    @MainActor
    func test_perpsService_shownOnlyForMultichainWallet() async {
        let shelves = TradingShelvesServiceSpy(snapshot: makeEmptySnapshot())
        let enabled = makeViewModel(
            shelvesService: shelves,
            onOpenPerps: {}
        )
        XCTAssertEqual(enabled.services.map(\.kind), [.perps])

        let legacy = makeViewModel(
            shelvesService: shelves,
            walletsStore: makeWalletsStore(wallets: [makeWallet()]),
            onOpenPerps: {}
        )
        XCTAssertTrue(legacy.services.isEmpty)

        let flagOff = makeViewModel(shelvesService: shelves)
        XCTAssertTrue(flagOff.services.isEmpty)

        let multichainWallet = makeWallet(
            id: "multichain",
            multichain: .multichain(
                .init(
                    walletId: "wallet",
                    addresses: [MultichainWalletAddress(chain: .eth, address: "0xwallet")]
                )
            )
        )
        let legacyWallet = makeWallet(id: "legacy")
        let walletsStore = makeWalletsStore(wallets: [multichainWallet, legacyWallet])
        let switching = makeViewModel(
            shelvesService: shelves,
            walletsStore: walletsStore,
            onOpenPerps: {}
        )
        XCTAssertEqual(switching.services.map(\.kind), [.perps])
        _ = await walletsStore.makeWalletActive(legacyWallet)
        XCTAssertTrue(switching.services.isEmpty)
    }
}

private extension TradeViewModelTests {
    @MainActor
    func makeViewModel(
        shelvesService: TradingShelvesService,
        favoriteAssetsService: TradingFavoriteAssetsService = FavoriteAssetsServiceSpy(),
        walletsStore: WalletsStore? = nil,
        perpsShelfMarketsLoader: (() async throws -> [PerpsMarketSummary])? = nil,
        onOpenAssetList: @escaping (TradingAssetCategory, MultichainAssetSearchSort) -> Void = { _, _ in },
        onOpenPerps: (() -> Void)? = nil,
        onOpenPerpsMarket: ((Int64) -> Void)? = nil,
        onOpenAssetDetails: @escaping (TradeAssetDetailsViewModel.PreviewContext) -> Void = { _ in }
    ) -> TradeViewModel {
        let formattersAssembly = FormattersAssembly()
        let walletsStore = walletsStore ?? makeWalletsStore(wallets: [
            makeWallet(
                multichain: .multichain(
                    .init(
                        walletId: "wallet",
                        addresses: [MultichainWalletAddress(chain: .eth, address: "0xwallet")]
                    )
                )
            ),
        ])
        return TradeViewModel(
            analyticsProvider: AnalyticsProvider(
                analyticsServices: [],
                uniqueIdProvider: CoreAssembly().uniqueIdProvider,
                appInfoProvider: CoreAssembly().appInfoProvider,
                keysCountryCodeProvider: CoreAssembly().keysCountryCodeProvider
            ),
            analyticsSource: .deepLink,
            walletsStore: walletsStore,
            shelvesService: shelvesService,
            favoriteAssetsService: favoriteAssetsService,
            perpsShelfMarketsLoader: perpsShelfMarketsLoader,
            signedAmountFormatter: formattersAssembly.signedAmountFormatter,
            onOpenAssetList: onOpenAssetList,
            onOpenPerps: onOpenPerps,
            onOpenPerpsMarket: onOpenPerpsMarket,
            onOpenAssetDetails: onOpenAssetDetails
        )
    }

    func makeWalletsStore(wallets: [Wallet]? = nil) -> WalletsStore {
        let wallets = wallets ?? [makeWallet()]
        return WalletsStore(
            keeperInfoStore: KeeperInfoStore(
                keeperInfoRepository: TradeKeeperInfoRepositoryStub(
                    keeperInfo: KeeperInfo(
                        wallets: wallets,
                        currentWallet: wallets[0],
                        currency: .defaultCurrency,
                        securitySettings: SecuritySettings(
                            isBiometryEnabled: false,
                            isLockScreen: false
                        ),
                        appSettings: KeeperInfo.AppSettings(
                            isSecureMode: false,
                            searchEngine: .duckduckgo
                        ),
                        country: .auto
                    )
                )
            )
        )
    }

    func makeWallet(
        id: String = "wallet",
        multichain: MultichainWallet? = nil
    ) -> Wallet {
        Wallet(
            id: id,
            identity: WalletIdentity(
                network: .mainnet,
                kind: .Regular(
                    PublicKey(data: Data(repeating: 0x01, count: 32)),
                    .v4R2
                )
            ),
            metaData: WalletMetaData(
                label: "Test wallet \(id)",
                tintColor: .defaultColor,
                icon: .icon(.wallet)
            ),
            setupSettings: WalletSetupSettings(isSetupFinished: true),
            batterySettings: BatterySettings(),
            multichain: multichain
        )
    }

    func makeEmptySnapshot() -> TradingShelvesSnapshot {
        TradingShelvesSnapshot(
            generatedAt: .now,
            currency: .USD,
            shelves: []
        )
    }

    func makePerpsMarket(marketID: Int64, symbol: String) -> PerpsMarketSummary {
        PerpsMarketSummary(
            marketId: marketID,
            symbol: symbol,
            name: symbol,
            iconURL: nil,
            maxLeverage: 40,
            price: 100,
            priceChangePercent: 1.25,
            volume24h: 1000
        )
    }

    func makeSnapshot(title: String) -> TradingShelvesSnapshot {
        TradingShelvesSnapshot(
            generatedAt: .now,
            currency: .USD,
            shelves: [
                TradingShelf(
                    id: title,
                    title: title,
                    grids: []
                ),
            ]
        )
    }

    func makeGridSelectionSnapshot() -> TradingShelvesSnapshot {
        TradingShelvesSnapshot(
            generatedAt: .now,
            currency: .USD,
            shelves: [
                TradingShelf(
                    id: "shelf-1",
                    title: "Shelf 1",
                    grids: [
                        makeGrid(id: "popular_grid"),
                    ]
                ),
                TradingShelf(
                    id: "shelf-2",
                    title: "Shelf 2",
                    grids: [
                        makeGrid(id: "default_grid"),
                        makeGrid(id: "target_grid"),
                    ]
                ),
            ]
        )
    }

    func makeGroupedSelectionSnapshot() -> TradingShelvesSnapshot {
        TradingShelvesSnapshot(
            generatedAt: .now,
            currency: .USD,
            shelves: [
                TradingShelf(
                    id: "shelf-grouped",
                    title: "Top tokens",
                    groups: [
                        TradingShelfGroup(
                            id: "ton",
                            title: "TON",
                            grids: [
                                makeGrid(id: "shared_grid", symbol: "TON"),
                                makeGrid(id: "ton_grid", symbol: "JET"),
                            ]
                        ),
                        TradingShelfGroup(
                            id: "tron",
                            title: "TRON",
                            grids: [
                                makeGrid(id: "shared_grid", symbol: "USDT"),
                                makeGrid(id: "tron_grid", symbol: "TRX"),
                            ]
                        ),
                    ]
                ),
            ]
        )
    }

    func makeGrid(
        id: String,
        symbol: String = "TON"
    ) -> TradingShelfGrid {
        TradingShelfGrid(
            id: id,
            name: id,
            source: "api",
            seeAllCategory: .all,
            items: [
                TradingMarketItem(
                    id: "ton/mainnet/coin",
                    symbol: symbol,
                    name: symbol,
                    category: .tokens,
                    imageURL: nil,
                    price: nil,
                    change24hPercent: nil,
                    verification: .whitelist
                ),
            ]
        )
    }

    func makeFavoriteAsset(id: String, symbol: String) -> TradingFavoriteAsset {
        TradingFavoriteAsset(
            id: id,
            symbol: symbol,
            imageURL: nil,
            addedAt: .now
        )
    }

    func makeMarketItem(
        id: String,
        symbol: String,
        category: TradingAssetCategory,
        change: String
    ) -> TradingMarketItem {
        TradingMarketItem(
            id: id,
            symbol: symbol,
            name: symbol,
            category: category,
            imageURL: nil,
            price: nil,
            change24hPercent: Decimal(string: change),
            verification: .whitelist
        )
    }

    func makeMultichainAsset(
        id: String,
        verification: MultichainAssetVerification
    ) -> MultichainAsset {
        MultichainAsset(
            asset: MultichainAssetDetails(
                assetId: id,
                name: "Ethereum",
                symbol: "ETH",
                decimals: 18,
                image: "",
                verification: verification
            ),
            price: MultichainAssetPrice(
                prices: [:],
                diff24h: [:],
                diff7d: [:],
                diff30d: [:]
            ),
            balance: .zero
        )
    }

    func waitUntil(
        timeout: TimeInterval = 2,
        intervalNanoseconds: UInt64 = 10_000_000,
        condition: @escaping () async -> Bool
    ) async {
        let deadline = Date().addingTimeInterval(timeout)

        while Date() < deadline {
            if await condition() {
                return
            }

            try? await Task.sleep(nanoseconds: intervalNanoseconds)
        }

        XCTFail("Timed out waiting for condition")
    }
}

private actor TradingShelvesServiceSpy: TradingShelvesService {
    let snapshot: TradingShelvesSnapshot
    let loadShelvesGate: TestGate?
    let loadFailure: LoadShelvesFailure?

    func shelves(for mode: TradingShelvesMode) async -> TradingShelvesSnapshot? {
        snapshot
    }

    init(
        snapshot: TradingShelvesSnapshot,
        loadShelvesGate: TestGate? = nil,
        loadFailure: LoadShelvesFailure? = nil
    ) {
        self.snapshot = snapshot
        self.loadShelvesGate = loadShelvesGate
        self.loadFailure = loadFailure
    }

    func loadShelves(for mode: TradingShelvesMode) async throws(LoadShelvesFailure) -> TradingShelvesSnapshot {
        await loadShelvesGate?.enter()
        if let loadFailure {
            throw loadFailure
        }
        return snapshot
    }
}

private actor ModeTradingShelvesServiceSpy: TradingShelvesService {
    private let snapshots: [TradingShelvesMode: TradingShelvesSnapshot]
    private let loadGates: [TradingShelvesMode: TestGate]
    private(set) var loadCalls = [TradingShelvesMode]()

    init(
        snapshots: [TradingShelvesMode: TradingShelvesSnapshot],
        loadGates: [TradingShelvesMode: TestGate] = [:]
    ) {
        self.snapshots = snapshots
        self.loadGates = loadGates
    }

    func shelves(for mode: TradingShelvesMode) async -> TradingShelvesSnapshot? {
        snapshots[mode]
    }

    func loadShelves(for mode: TradingShelvesMode) async throws(LoadShelvesFailure) -> TradingShelvesSnapshot {
        loadCalls.append(mode)
        await loadGates[mode]?.enter()
        guard let snapshot = snapshots[mode] else {
            throw .apiError(message: nil)
        }
        return snapshot
    }
}

private final class TradeKeeperInfoRepositoryStub: KeeperInfoRepository {
    private var keeperInfo: KeeperInfo?

    init(keeperInfo: KeeperInfo?) {
        self.keeperInfo = keeperInfo
    }

    func getKeeperInfo() throws -> KeeperInfo {
        guard let keeperInfo else {
            throw TradeKeeperInfoRepositoryError.missingKeeperInfo
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

private enum TradeKeeperInfoRepositoryError: Error {
    case missingKeeperInfo
}

private actor FavoriteAssetsServiceSpy: TradingFavoriteAssetsService {
    let storedAssets: [TradingFavoriteAsset]
    let storedMarketItems: [String: TradingMarketItem]
    let storedCachedMarketItems: [String: TradingMarketItem]?
    let marketItemsGate: TestGate?
    private(set) var favoriteContexts = [(isFavorite: Bool, context: TradingFavoriteAssetContext)]()
    private(set) var updatedContexts = [TradingFavoriteAssetContext]()
    private(set) var marketItemsAssetIDs = [[String]]()
    private(set) var marketItemsForceRefreshFlags = [Bool]()

    var assets: [TradingFavoriteAsset] {
        get async { storedAssets }
    }

    func cachedMarketItems(assetIDs: [String]) async -> [String: TradingMarketItem] {
        guard let storedCachedMarketItems else {
            return [:]
        }
        return storedCachedMarketItems.filter { assetIDs.contains($0.key) }
    }

    init(
        assets: [TradingFavoriteAsset] = [],
        marketItems: [String: TradingMarketItem] = [:],
        cachedMarketItems: [String: TradingMarketItem]? = nil,
        marketItemsGate: TestGate? = nil
    ) {
        self.storedAssets = assets
        self.storedMarketItems = marketItems
        self.storedCachedMarketItems = cachedMarketItems
        self.marketItemsGate = marketItemsGate
    }

    func isFavorite(id: String) async -> Bool {
        storedAssets.contains { $0.id == id }
    }

    func setFavorite(_ isFavorite: Bool, context: TradingFavoriteAssetContext) async {
        favoriteContexts.append((isFavorite, context))
    }

    func updateAsset(_ context: TradingFavoriteAssetContext) async {
        updatedContexts.append(context)
    }

    func marketItems(assetIDs: [String], forceRefresh: Bool) async -> [String: TradingMarketItem] {
        marketItemsAssetIDs.append(assetIDs)
        marketItemsForceRefreshFlags.append(forceRefresh)
        await marketItemsGate?.enter()
        return storedMarketItems
    }
}

/// Deterministic suspension point for tests, made of two one-shot events.
/// A spy calls `enter()` to mark arrival and suspend; the test observes the
/// intermediate state via `waitUntilEntered()`, then resumes the spy with
/// `open()`. Replaces real-time `Task.sleep` windows, which are flaky and slow.
private enum PerpsShelfTestError: Error {
    case failed
}

private actor TestGate {
    private var didEnter = false
    private var isOpen = false
    private var enterWaiters = [CheckedContinuation<Void, Never>]()
    private var openWaiters = [CheckedContinuation<Void, Never>]()

    func enter() async {
        didEnter = true
        resume(&enterWaiters)

        guard !isOpen else { return }
        await withCheckedContinuation { openWaiters.append($0) }
    }

    func waitUntilEntered() async {
        guard !didEnter else { return }
        await withCheckedContinuation { enterWaiters.append($0) }
    }

    func open() {
        isOpen = true
        resume(&openWaiters)
    }

    private func resume(_ waiters: inout [CheckedContinuation<Void, Never>]) {
        let pending = waiters
        waiters = []
        pending.forEach { $0.resume() }
    }
}
