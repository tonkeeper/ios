@testable import App
import AppUI
import Combine
import Foundation
@testable import KeeperCore
import TKLocalize
import TKUIKit
import TonSwift
import XCTest

final class MultichainHistoryViewModelTests: XCTestCase {
    @MainActor
    func test_viewDidLoad_loadsFirstPageForAllNetworksAndAllTypes() async throws {
        let service = MultichainServiceSpy()
        await service.setActivityPlans([
            .success(page(activities: [activity(id: "all-1")], nextCursor: nil)),
        ])
        let viewModel = makeViewModel(multichainService: service)

        viewModel.viewDidLoad()

        await waitUntil {
            await MainActor.run {
                self.currentActivities(in: viewModel.currentQueryViewModel).count == 1
            }
        }

        let requests = await service.activityRequests()
        let request = try XCTUnwrap(requests.first)
        XCTAssertEqual(request.walletId, "wallet")
        XCTAssertEqual(request.limit, 30)
        XCTAssertNil(request.cursor)
        XCTAssertNil(request.chain)
        XCTAssertNil(request.activityTypeFilter)
        XCTAssertEqual(currentActivities(in: viewModel.currentQueryViewModel).map(\.txIds), [["all-1"]])
        XCTAssertEqual(currentItems(in: viewModel.currentQueryViewModel).map(\.id.txIds), [["all-1"]])
        XCTAssertTrue(
            try viewModel.isTypeFilterActionBarVisible(
                for: XCTUnwrap(viewModel.currentQueryViewModel)
            )
        )
    }

    @MainActor
    func test_perpetualsFilter_isOfferedOnlyWhenPerpsAreEnabled() {
        let disabled = makeViewModel(multichainService: MultichainServiceSpy())
        XCTAssertFalse(disabled.typeFilterItems.map(\.id).contains(.perps))

        let enabled = makeViewModel(multichainService: MultichainServiceSpy(), isPerpsEnabled: true)
        XCTAssertTrue(enabled.typeFilterItems.map(\.id).contains(.perps))
    }

    @MainActor
    func test_allTypesRequest_asksForPerpsOnlyWhenPerpsAreEnabled() async throws {
        for isPerpsEnabled in [false, true] {
            let service = MultichainServiceSpy()
            await service.setActivityPlans([.success(page(activities: [], nextCursor: nil))])
            let viewModel = makeViewModel(multichainService: service, isPerpsEnabled: isPerpsEnabled)

            viewModel.viewDidLoad()

            await waitUntil {
                let requests = await service.activityRequests()
                return !requests.isEmpty
            }
            let requests = await service.activityRequests()
            let request = try XCTUnwrap(requests.first)
            XCTAssertNil(request.activityTypeFilter)
            XCTAssertEqual(request.showPerps, isPerpsEnabled ? true : nil)
        }
    }

    @MainActor
    func test_spamFilter_doesNotAskForPerpsItWouldDiscard() async throws {
        let service = MultichainServiceSpy()
        await service.setActivityPlans(
            (1 ... 12).map { _ in .success(page(activities: [], nextCursor: nil)) }
        )
        let viewModel = makeViewModel(multichainService: service, isPerpsEnabled: true)
        viewModel.viewDidLoad()
        await waitUntil {
            let requests = await service.activityRequests()
            return !requests.isEmpty
        }

        viewModel.selectTypeFilter(.spam)

        await waitUntil {
            let requests = await service.activityRequests()
            return requests.count > 1
        }
        let recorded = await service.activityRequests()
        let request = try XCTUnwrap(recorded.last)
        XCTAssertNil(request.activityTypeFilter)
        XCTAssertNil(request.showPerps)
    }

    @MainActor
    func test_perpetualsFilter_requestsThePerpsUmbrellaType() async throws {
        let service = MultichainServiceSpy()
        await service.setActivityPlans([
            .success(page(activities: [], nextCursor: nil)),
            .success(page(activities: [], nextCursor: nil)),
        ])
        let viewModel = makeViewModel(multichainService: service, isPerpsEnabled: true)
        viewModel.viewDidLoad()
        await waitUntil {
            let requests = await service.activityRequests()
            return !requests.isEmpty
        }

        viewModel.selectTypeFilter(.perps)

        await waitUntil {
            let requests = await service.activityRequests()
            return requests.count > 1
        }
        let recorded = await service.activityRequests()
        let request = try XCTUnwrap(recorded.last)
        XCTAssertEqual(request.activityTypeFilter, .perps)
        XCTAssertEqual(request.showPerps, true)
    }

    @MainActor
    func test_contentViewModel_keepsIndependentInstancesForNetworkAndTypeCategories() {
        let service = MultichainServiceSpy()
        let viewModel = makeViewModel(multichainService: service)

        let allCategory = MultichainHistoryCategory.chain(
            chainFilter: .all,
            typeFilter: .all
        )
        let ethSendCategory = MultichainHistoryCategory.chain(
            chainFilter: .chain(.eth),
            typeFilter: .send
        )

        let allViewModel = viewModel.contentViewModel(for: allCategory)
        let ethSendViewModel = viewModel.contentViewModel(for: ethSendCategory)

        XCTAssertTrue(viewModel.contentViewModel(for: allCategory) === allViewModel)
        XCTAssertTrue(viewModel.contentViewModel(for: ethSendCategory) === ethSendViewModel)
        XCTAssertFalse(allViewModel === ethSendViewModel)
    }

    @MainActor
    func test_contentDescriptors_arePreparedOnlyForActivatedCategories() async {
        let service = MultichainServiceSpy()
        await service.setActivityPlans([
            .success(page(activities: [], nextCursor: nil)),
            .success(page(activities: [], nextCursor: nil)),
        ])
        let viewModel = makeViewModel(multichainService: service)
        let allCategory = MultichainHistoryCategory.chain(
            chainFilter: .all,
            typeFilter: .all
        )
        let ethCategory = MultichainHistoryCategory.chain(
            chainFilter: .chain(.eth),
            typeFilter: .all
        )

        viewModel.viewDidLoad()

        XCTAssertEqual(viewModel.contentDescriptors.map(\.id), [allCategory])
        XCTAssertEqual(viewModel.contentDescriptors.map(\.isActive), [true])

        viewModel.selectChainFilter(.chain(.eth))

        XCTAssertEqual(viewModel.contentDescriptors.map(\.id), [allCategory, ethCategory])
        XCTAssertEqual(viewModel.contentDescriptors.map(\.isActive), [false, true])
    }

    @MainActor
    func test_typeFilterItems_exposeAllSentReceivedSwapAndSpamFilters() {
        let service = MultichainServiceSpy()
        let viewModel = makeViewModel(multichainService: service)

        XCTAssertEqual(
            viewModel.typeFilterItems.map(\.id),
            [.all, .send, .receive, .swap, .spam]
        )
    }

    @MainActor
    func test_chainTabs_orderNetworksByDisplayPriorityRegardlessOfDerivationOrder() {
        let service = MultichainServiceSpy()
        let viewModel = makeViewModel(
            multichainService: service,
            addresses: [
                MultichainWalletAddress(chain: .ton, address: "ton"),
                MultichainWalletAddress(chain: .tron, address: "tron"),
                MultichainWalletAddress(chain: .eth, address: "eth"),
                MultichainWalletAddress(chain: .base, address: "base"),
                MultichainWalletAddress(chain: .btc, address: "btc"),
            ]
        )

        viewModel.viewDidLoad()

        XCTAssertEqual(
            viewModel.chainTabs.map(\.id),
            [.all, .chain(.ton), .chain(.tron), .chain(.eth), .chain(.btc), .chain(.base)]
        )
    }

    @MainActor
    func test_spamTypeFilter_locallyKeepsOnlySpamActivitiesFromLoadedPages() async {
        let service = MultichainServiceSpy()
        await service.setActivityPlans([
            .success(
                page(
                    activities: [
                        activity(id: "clean", isSpam: false),
                        activity(id: "spam", isSpam: true),
                    ],
                    nextCursor: nil
                )
            ),
        ])
        let queryViewModel = makeQueryViewModel(
            multichainService: service,
            category: .chain(chainFilter: .all, typeFilter: .spam)
        )

        queryViewModel.appeared()
        await waitUntil {
            await MainActor.run {
                if case .loaded = queryViewModel.state {
                    return true
                }
                return false
            }
        }

        XCTAssertEqual(currentItems(in: queryViewModel).map(\.id.txIds), [["spam"]])
        // Spam tab fetches all types (no server-side spam filter) and filters client-side.
        let requests = await service.activityRequests()
        XCTAssertEqual(requests.map(\.activityTypeFilter), [nil])
    }

    @MainActor
    func test_spamTypeFilter_autoAdvancesPagesWhileClientFilterLeavesListEmpty() async {
        let service = MultichainServiceSpy()
        await service.setActivityPlans([
            .success(page(activities: [activity(id: "clean", isSpam: false)], nextCursor: "cursor-2")),
            .success(page(activities: [activity(id: "spam", isSpam: true)], nextCursor: nil)),
        ])
        let queryViewModel = makeQueryViewModel(
            multichainService: service,
            category: .chain(chainFilter: .all, typeFilter: .spam)
        )

        queryViewModel.appeared()
        await waitUntil {
            await MainActor.run {
                self.currentItems(in: queryViewModel).map(\.id.txIds) == [["spam"]]
            }
        }

        // No visible row to drive `loadNextPageIfNeeded`; pagination must self-advance.
        let requests = await service.activityRequests()
        XCTAssertEqual(requests.map(\.cursor), [nil, "cursor-2"])
    }

    @MainActor
    func test_spamTypeFilter_autoAdvancesWhenFilteredNextPageAddsNoVisibleRows() async {
        let service = MultichainServiceSpy()
        await service.setActivityPlans([
            .success(page(activities: [activity(id: "spam-1", isSpam: true)], nextCursor: "cursor-2")),
            .success(page(activities: [activity(id: "clean", isSpam: false)], nextCursor: "cursor-3")),
            .success(page(activities: [activity(id: "spam-2", isSpam: true)], nextCursor: nil)),
        ])
        let queryViewModel = makeQueryViewModel(
            multichainService: service,
            category: .chain(chainFilter: .all, typeFilter: .spam)
        )

        queryViewModel.appeared()
        await waitUntil {
            await MainActor.run {
                self.currentItems(in: queryViewModel).map(\.id.txIds) == [["spam-1"]]
            }
        }

        // Scroll trigger loads page 2, which is fully spam-filtered → zero new visible rows.
        // Without self-advance, pagination stalls here even though cursor-3 remains.
        guard let lastItem = currentItems(in: queryViewModel).last else {
            return XCTFail("Expected loaded item")
        }
        queryViewModel.loadNextPageIfNeeded(currentItem: lastItem)

        await waitUntil {
            await MainActor.run {
                self.currentItems(in: queryViewModel).map(\.id.txIds) == [["spam-1"], ["spam-2"]]
            }
        }

        let requests = await service.activityRequests()
        XCTAssertEqual(requests.map(\.cursor), [nil, "cursor-2", "cursor-3"])
    }

    @MainActor
    func test_spamTypeFilter_resumesAutoAdvanceWhenReappearingAfterInterruptedWhileEmpty() async {
        let service = MultichainServiceSpy()
        await service.setActivityPlans([
            .success(page(activities: [activity(id: "clean", isSpam: false)], nextCursor: "cursor-2")),
            .success(
                page(activities: [activity(id: "spam", isSpam: true)], nextCursor: nil),
                delayNanoseconds: 1_000_000_000
            ),
        ])
        let queryViewModel = makeQueryViewModel(
            multichainService: service,
            category: .chain(chainFilter: .all, typeFilter: .spam)
        )

        queryViewModel.appeared()
        // Page 1 is fully spam-filtered → auto-advance dispatches the gated page 2.
        await waitUntil {
            await service.activityRequests().count == 2
        }

        // Leaving mid-walk cancels the in-flight page and freezes an empty `.loaded` (hasNextPage: true).
        queryViewModel.disappeared()

        // Reappearing must resume the walk; no visible row exists to drive loadNextPageIfNeeded.
        await service.setActivityPlans([
            .success(page(activities: [activity(id: "spam", isSpam: true)], nextCursor: nil)),
        ])
        queryViewModel.appeared()

        await waitUntil {
            await MainActor.run {
                self.currentItems(in: queryViewModel).map(\.id.txIds) == [["spam"]]
            }
        }
    }

    @MainActor
    func test_autoAdvance_stopsAfterSpendingThePageBudget() async {
        let service = MultichainServiceSpy()
        await service.setActivityPlans(
            (1 ... 15).map { index in
                .success(page(activities: [activity(id: "clean-\(index)", isSpam: false)], nextCursor: "cursor-\(index + 1)"))
            }
        )
        let queryViewModel = makeQueryViewModel(
            multichainService: service,
            category: .chain(chainFilter: .all, typeFilter: .spam)
        )

        queryViewModel.appeared()
        // Every page is fully spam-filtered, so the walk is bounded by the budget, not by the cursor.
        await waitUntil {
            await service.activityRequests().count == 11
        }
        try? await Task.sleep(nanoseconds: 200_000_000)

        let requests = await service.activityRequests()
        XCTAssertEqual(requests.count, 11)
        XCTAssertTrue(currentItems(in: queryViewModel).isEmpty)
        if case .loaded = queryViewModel.state {
        } else {
            XCTFail("Expected the walk to settle instead of loading further pages")
        }
    }

    @MainActor
    func test_autoAdvance_refillsThePageBudgetOnTheNextAppearance() async {
        let service = MultichainServiceSpy()
        await service.setActivityPlans(
            (1 ... 15).map { index in
                .success(page(activities: [activity(id: "clean-\(index)", isSpam: false)], nextCursor: "cursor-\(index + 1)"))
            }
        )
        let queryViewModel = makeQueryViewModel(
            multichainService: service,
            category: .chain(chainFilter: .all, typeFilter: .spam)
        )

        queryViewModel.appeared()
        await waitUntil {
            await service.activityRequests().count == 11
        }

        queryViewModel.appeared()

        await waitUntil {
            await service.activityRequests().count > 11
        }
        let requests = await service.activityRequests()
        XCTAssertEqual(requests.dropFirst(11).first?.cursor, "cursor-12")
    }

    @MainActor
    func test_changingCategory_cancelsInactiveSpamAutoPagination() async {
        let initialGate = MultichainHistoryTestGate()
        let spamGate = MultichainHistoryTestGate()
        let service = MultichainServiceSpy()
        await service.setActivityPlans([
            .success(page(activities: [], nextCursor: nil), gate: initialGate),
            .success(page(activities: [activity(id: "clean-1", isSpam: false)], nextCursor: "cursor-2")),
            .success(
                page(activities: [activity(id: "clean-2", isSpam: false)], nextCursor: "cursor-3"),
                gate: spamGate
            ),
        ])
        let viewModel = makeViewModel(multichainService: service)

        viewModel.viewDidLoad()
        await initialGate.waitUntilEntered()
        await initialGate.open()

        viewModel.selectTypeFilter(.spam)
        guard let spamQueryViewModel = viewModel.currentQueryViewModel else {
            return XCTFail("Expected spam query view model")
        }
        await spamGate.waitUntilEntered()

        viewModel.selectTypeFilter(.all)
        if case .loaded = spamQueryViewModel.state {
        } else {
            XCTFail("Expected inactive query pagination to be cancelled")
        }
        await spamGate.open()
    }

    @MainActor
    func test_allTypeFilter_hidesSpamActivitiesFromLoadedPages() async {
        let service = MultichainServiceSpy()
        await service.setActivityPlans([
            .success(
                page(
                    activities: [
                        activity(id: "clean", isSpam: false),
                        activity(id: "spam", isSpam: true),
                    ],
                    nextCursor: nil
                )
            ),
        ])
        let queryViewModel = makeQueryViewModel(
            multichainService: service,
            category: .chain(chainFilter: .all, typeFilter: .all)
        )

        queryViewModel.appeared()
        await waitUntil {
            await MainActor.run {
                if case .loaded = queryViewModel.state {
                    return true
                }
                return false
            }
        }

        XCTAssertEqual(currentItems(in: queryViewModel).map(\.id.txIds), [["clean"]])
    }

    @MainActor
    func test_sendTypeFilter_hidesSpamActivitiesFromLoadedPages() async {
        let service = MultichainServiceSpy()
        await service.setActivityPlans([
            .success(
                page(
                    activities: [
                        activity(id: "clean", activityType: .send, isSpam: false),
                        activity(id: "spam", activityType: .send, isSpam: true),
                    ],
                    nextCursor: nil
                )
            ),
        ])
        let queryViewModel = makeQueryViewModel(
            multichainService: service,
            category: .chain(chainFilter: .all, typeFilter: .send)
        )

        queryViewModel.appeared()
        await waitUntil {
            await MainActor.run {
                if case .loaded = queryViewModel.state {
                    return true
                }
                return false
            }
        }

        XCTAssertEqual(currentItems(in: queryViewModel).map(\.id.txIds), [["clean"]])
    }

    @MainActor
    func test_hidesDustTransactions_sendsHideDustWithEveryPageRequest() async {
        let service = MultichainServiceSpy()
        await service.setActivityPlans([
            .success(page(activities: [activity(id: "a1")], nextCursor: "cursor-2")),
            .success(page(activities: [activity(id: "a2")], nextCursor: nil)),
        ])
        let queryViewModel = makeQueryViewModel(
            multichainService: service,
            hidesDustTransactions: true
        )

        queryViewModel.appeared()
        await waitUntil {
            await MainActor.run {
                if case .loaded = queryViewModel.state {
                    return true
                }
                return false
            }
        }
        queryViewModel.loadNextPageIfNeeded(currentItem: currentItems(in: queryViewModel)[0])
        await waitUntil {
            await service.activityRequests().count == 2
        }

        let requests = await service.activityRequests()
        XCTAssertEqual(requests.map(\.hideDust), [true, true])
    }

    @MainActor
    func test_defaultFilters_dontSendHideDust() async {
        let service = MultichainServiceSpy()
        await service.setActivityPlans([
            .success(page(activities: [activity(id: "a1")], nextCursor: nil)),
        ])
        let queryViewModel = makeQueryViewModel(multichainService: service)

        queryViewModel.appeared()
        await waitUntil {
            await MainActor.run {
                if case .loaded = queryViewModel.state {
                    return true
                }
                return false
            }
        }

        let requests = await service.activityRequests()
        XCTAssertEqual(requests.map(\.hideDust), [nil])
    }

    @MainActor
    func test_hidesDustTransactions_isNotSentForSpamFolder() async {
        let service = MultichainServiceSpy()
        await service.setActivityPlans([
            .success(page(activities: [activity(id: "spam", isSpam: true)], nextCursor: nil)),
        ])
        let queryViewModel = makeQueryViewModel(
            multichainService: service,
            category: .chain(chainFilter: .all, typeFilter: .spam),
            hidesDustTransactions: true
        )

        queryViewModel.appeared()
        await waitUntil {
            await MainActor.run {
                if case .loaded = queryViewModel.state {
                    return true
                }
                return false
            }
        }

        let requests = await service.activityRequests()
        XCTAssertEqual(requests.map(\.hideDust), [nil])
    }

    @MainActor
    func test_setHidesDustTransactions_refetchesCurrentCategoryAndReportsChange() async {
        let service = MultichainServiceSpy()
        await service.setActivityPlans([
            .success(page(activities: [activity(id: "a1")], nextCursor: nil)),
            .success(page(activities: [activity(id: "a2")], nextCursor: nil)),
        ])
        let viewModel = makeViewModel(multichainService: service)
        var reportedDust: Bool?
        viewModel.onHistoryFiltersChange = {
            reportedDust = $0
        }

        viewModel.viewDidLoad()
        await waitUntil {
            await service.activityRequests().count == 1
        }

        viewModel.setHidesDustTransactions(true)
        await waitUntil {
            await service.activityRequests().count == 2
        }

        let requests = await service.activityRequests()
        XCTAssertEqual(requests.map(\.hideDust), [nil, true])
        XCTAssertEqual(reportedDust, true)
        XCTAssertTrue(viewModel.hidesDustTransactions)
    }

    @MainActor
    func test_setHidesDustTransactions_withEqualValue_doesNotRefetchOrReport() async {
        let service = MultichainServiceSpy()
        await service.setActivityPlans([
            .success(page(activities: [activity(id: "a1")], nextCursor: nil)),
        ])
        let viewModel = makeViewModel(multichainService: service)
        var reportCount = 0
        viewModel.onHistoryFiltersChange = { _ in reportCount += 1 }

        viewModel.viewDidLoad()
        await waitUntil {
            await service.activityRequests().count == 1
        }

        viewModel.setHidesDustTransactions(false)

        let requests = await service.activityRequests()
        XCTAssertEqual(requests.count, 1)
        XCTAssertEqual(reportCount, 0)
    }

    @MainActor
    func test_typeFilterActionBarVisibility_hidesAllFilterOnlyWhenCurrentListIsEmpty() async throws {
        let service = MultichainServiceSpy()
        await service.setActivityPlans([
            .success(page(activities: [], nextCursor: nil)),
            .success(page(activities: [], nextCursor: nil)),
        ])
        let viewModel = makeViewModel(multichainService: service)

        viewModel.viewDidLoad()

        await waitUntil {
            await MainActor.run {
                viewModel.currentQueryViewModel?.presentation.placeholder == .empty
            }
        }

        let allQueryViewModel = try XCTUnwrap(viewModel.currentQueryViewModel)
        XCTAssertFalse(viewModel.isTypeFilterActionBarVisible(for: allQueryViewModel))

        viewModel.selectTypeFilter(.send)

        let sendQueryViewModel = try XCTUnwrap(viewModel.currentQueryViewModel)
        XCTAssertTrue(viewModel.isTypeFilterActionBarVisible(for: sendQueryViewModel))
    }

    @MainActor
    func test_addFundsAction_isPassedToQueryViewModel() {
        let service = MultichainServiceSpy()
        var didAddFunds = false
        let viewModel = makeViewModel(
            multichainService: service,
            onAddFunds: {
                didAddFunds = true
            }
        )

        let queryViewModel = viewModel.contentViewModel(
            for: MultichainHistoryCategory.chain(
                chainFilter: .all,
                typeFilter: .all
            )
        )
        queryViewModel.addFunds()

        XCTAssertTrue(didAddFunds)
    }

    @MainActor
    func test_activitySubtitle_formatsTonRawAddressAsNonBounceableFriendlyAddress() async {
        let rawAddress = "0:0000000000000000000000000000000000000000000000000000000000000000"
        let ton = asset(
            symbol: "TON",
            assetId: "ton/mainnet/ton"
        )
        let service = MultichainServiceSpy()
        await service.setActivityPlans([
            .success(
                page(
                    activities: [
                        activity(
                            id: "ton-send",
                            activityType: .send,
                            outToken: ton,
                            inToken: ton,
                            fromChain: .ton,
                            toChain: .ton,
                            toAddress: rawAddress
                        ),
                    ],
                    nextCursor: nil
                )
            ),
        ])
        let queryViewModel = makeQueryViewModel(multichainService: service)

        queryViewModel.appeared()
        await waitUntil {
            await MainActor.run {
                self.currentItems(in: queryViewModel).count == 1
            }
        }

        XCTAssertEqual(currentItems(in: queryViewModel).first?.subtitle, "UQAA...AJKZ")
    }

    func test_transactionDetails_formatsTonRawAddressAsNonBounceableFriendlyAddress() throws {
        let rawAddress = "0:0000000000000000000000000000000000000000000000000000000000000000"
        let ton = asset(
            symbol: "TON",
            assetId: "ton/mainnet/ton"
        )
        let model = makeDetailsBuilder().build(
            activity: activity(
                id: "ton-send",
                activityType: .send,
                outToken: ton,
                inToken: ton,
                fromChain: .ton,
                toChain: .ton,
                toAddress: rawAddress
            )
        )

        let firstRow = try XCTUnwrap(model.rows.first)
        guard case let .address(_, address) = firstRow else {
            return XCTFail("Expected address row")
        }
        XCTAssertEqual(address, "UQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAJKZ")
    }

    func test_transactionDetails_hidesNetworkForNativeTokenAmount() {
        let ton = asset(
            symbol: "TON",
            assetId: "ton/mainnet/ton"
        )
        let model = makeDetailsBuilder().build(
            activity: activity(
                id: "ton-send",
                activityType: .send,
                outToken: ton,
                inToken: ton,
                fromChain: .ton,
                toChain: .ton
            )
        )

        XCTAssertNil(model.amountLines.first?.chain)
    }

    func test_transactionDetails_nativeTonAmountsUseGramSymbol() throws {
        let ton = asset(
            symbol: "TON",
            decimals: 9,
            assetId: "ton/mainnet/coin"
        )
        let model = makeDetailsBuilder().build(
            activity: activity(
                id: "ton-send",
                activityType: .send,
                outAmount: "1000000000",
                outToken: ton,
                inToken: ton,
                feeToken: ton,
                feeAmount: "100000000",
                fromChain: .ton,
                toChain: .ton
            )
        )

        XCTAssertEqual(model.amountLines.first?.amount, "\u{2212} 1 GRAM")
        guard case let .fee(_, amount, _) = try XCTUnwrap(feeRow(in: model)) else {
            return XCTFail("Expected fee row")
        }
        XCTAssertEqual(amount, "0.1 GRAM")
    }

    func test_transactionDetails_showsNetworkForTokenAmount() {
        let usdt = asset(
            symbol: "USDT",
            assetId: "ton/mainnet/jetton/usdt"
        )
        let model = makeDetailsBuilder().build(
            activity: activity(
                id: "ton-send",
                activityType: .send,
                outToken: usdt,
                inToken: usdt,
                fromChain: .ton,
                toChain: .ton
            )
        )

        XCTAssertEqual(model.amountLines.first?.chain, "TON")
    }

    func test_transactionDetails_receiveShowsFeeRow() throws {
        let eth = asset(
            symbol: "ETH",
            assetId: "eth/mainnet/eth"
        )
        let model = makeDetailsBuilder().build(
            activity: activity(
                id: "eth-receive",
                activityType: .receive,
                feeToken: eth,
                feeAmount: "1000000000000000000",
                feeAmountUsd: 0.12
            )
        )

        guard case let .fee(title, amount, fiatAmount) = try XCTUnwrap(feeRow(in: model)) else {
            return XCTFail("Expected fee row")
        }
        XCTAssertEqual(title, TKLocales.FeeMethodPicker.title)
        XCTAssertEqual(amount, "1 ETH")
        XCTAssertEqual(fiatAmount, "$\u{2009}0.12")
    }

    func test_transactionDetails_formatsNetworkFeeCompactly() throws {
        let eth = asset(
            symbol: "ETH",
            assetId: "eth/mainnet/eth"
        )
        let model = makeDetailsBuilder().build(
            activity: activity(
                id: "eth-receive",
                activityType: .receive,
                feeToken: eth,
                feeAmount: "1234567890000000000"
            )
        )

        guard case let .fee(_, amount, _) = try XCTUnwrap(feeRow(in: model)) else {
            return XCTFail("Expected fee row")
        }
        XCTAssertEqual(amount, "1.23 ETH")
    }

    func test_transactionDetails_showsTronResourceFeeInsteadOfZeroTRX() throws {
        let usdt = asset(
            symbol: "USDT",
            decimals: 6,
            assetId: "tron/mainnet/trc20/usdt"
        )
        let trx = asset(
            symbol: "TRX",
            decimals: 6,
            assetId: "tron/mainnet/trx"
        )
        let model = makeDetailsBuilder().build(
            activity: activity(
                id: "tron-send",
                activityType: .send,
                outToken: usdt,
                inToken: usdt,
                feeToken: trx,
                feeAmount: "0",
                fromChain: .tron,
                toChain: .tron,
                tronResource: MultichainTronResource(energy: 64285, bandwidth: 345)
            )
        )

        guard case let .fee(title, amount, secondary) = try XCTUnwrap(feeRow(in: model)) else {
            return XCTFail("Expected fee row")
        }
        XCTAssertEqual(title, TKLocales.FeeMethodPicker.title)
        XCTAssertEqual(
            amount,
            TKLocales.EventDetails.tronResourceEnergy(grouped(64285))
        )
        XCTAssertEqual(
            secondary,
            TKLocales.EventDetails.tronResourceBandwidth(grouped(345))
        )
    }

    func test_transactionDetails_showsEnergyOnlyTronResourceFee() throws {
        let usdt = asset(
            symbol: "USDT",
            decimals: 6,
            assetId: "tron/mainnet/trc20/usdt"
        )
        let model = makeDetailsBuilder().build(
            activity: activity(
                id: "tron-send",
                activityType: .send,
                outToken: usdt,
                inToken: usdt,
                fromChain: .tron,
                toChain: .tron,
                tronResource: MultichainTronResource(energy: 64285, bandwidth: 0)
            )
        )

        guard case let .fee(_, amount, secondary) = try XCTUnwrap(feeRow(in: model)) else {
            return XCTFail("Expected fee row")
        }
        XCTAssertEqual(amount, TKLocales.EventDetails.tronResourceEnergy(grouped(64285)))
        XCTAssertNil(secondary)
    }

    func test_transactionDetails_showsBandwidthOnlyTronResourceFee() throws {
        let usdt = asset(
            symbol: "USDT",
            decimals: 6,
            assetId: "tron/mainnet/trc20/usdt"
        )
        let model = makeDetailsBuilder().build(
            activity: activity(
                id: "tron-send",
                activityType: .send,
                outToken: usdt,
                inToken: usdt,
                fromChain: .tron,
                toChain: .tron,
                tronResource: MultichainTronResource(energy: 0, bandwidth: 345)
            )
        )

        guard case let .fee(_, amount, secondary) = try XCTUnwrap(feeRow(in: model)) else {
            return XCTFail("Expected fee row")
        }
        XCTAssertEqual(amount, TKLocales.EventDetails.tronResourceBandwidth(grouped(345)))
        XCTAssertNil(secondary)
    }

    func test_transactionDetails_keepsBurnedTRXFeeWhenPresent() throws {
        let usdt = asset(
            symbol: "USDT",
            decimals: 6,
            assetId: "tron/mainnet/trc20/usdt"
        )
        let trx = asset(
            symbol: "TRX",
            decimals: 6,
            assetId: "tron/mainnet/trx"
        )
        let model = makeDetailsBuilder().build(
            activity: activity(
                id: "tron-send",
                activityType: .send,
                outToken: usdt,
                inToken: usdt,
                feeToken: trx,
                feeAmount: "1000000",
                fromChain: .tron,
                toChain: .tron,
                tronResource: MultichainTronResource(energy: 64285, bandwidth: 345)
            )
        )

        guard case let .fee(_, amount, _) = try XCTUnwrap(feeRow(in: model)) else {
            return XCTFail("Expected fee row")
        }
        XCTAssertEqual(amount, "1 TRX")
    }

    func test_transactionDetails_showsBatteryChargesForBatteryPaidTronSend() throws {
        let usdt = asset(
            symbol: "USDT",
            decimals: 6,
            assetId: "tron/mainnet/trc20/usdt"
        )
        let trx = asset(
            symbol: "TRX",
            decimals: 6,
            assetId: "tron/mainnet/trx"
        )
        let model = makeDetailsBuilder().build(
            activity: activity(
                id: "tron-send",
                activityType: .send,
                outToken: usdt,
                inToken: usdt,
                feeToken: trx,
                feeAmount: "0",
                fromChain: .tron,
                toChain: .tron,
                feeType: .battery,
                batteryCharges: 3
            )
        )

        guard case let .fee(title, amount, secondary) = try XCTUnwrap(feeRow(in: model)) else {
            return XCTFail("Expected fee row")
        }
        XCTAssertEqual(title, TKLocales.FeeMethodPicker.title)
        XCTAssertEqual(amount, "3 \(TKLocales.Battery.Refill.chargesCount(count: 3))")
        XCTAssertNil(secondary)
    }

    func test_transactionDetails_batteryChargesWinOverTronResourceAndBurnedTRX() throws {
        let usdt = asset(
            symbol: "USDT",
            decimals: 6,
            assetId: "tron/mainnet/trc20/usdt"
        )
        let trx = asset(
            symbol: "TRX",
            decimals: 6,
            assetId: "tron/mainnet/trx"
        )
        let model = makeDetailsBuilder().build(
            activity: activity(
                id: "tron-send",
                activityType: .send,
                outToken: usdt,
                inToken: usdt,
                feeToken: trx,
                feeAmount: "1000000",
                fromChain: .tron,
                toChain: .tron,
                tronResource: MultichainTronResource(energy: 64285, bandwidth: 345),
                feeType: .battery,
                batteryCharges: 1
            )
        )

        guard case let .fee(_, amount, secondary) = try XCTUnwrap(feeRow(in: model)) else {
            return XCTFail("Expected fee row")
        }
        XCTAssertEqual(amount, "1 \(TKLocales.Battery.Refill.chargesCount(count: 1))")
        XCTAssertNil(secondary)
    }

    func test_transactionDetails_showsZeroBatteryChargesAsReported() throws {
        let usdt = asset(
            symbol: "USDT",
            decimals: 6,
            assetId: "tron/mainnet/trc20/usdt"
        )
        let model = makeDetailsBuilder().build(
            activity: activity(
                id: "tron-send",
                activityType: .send,
                outToken: usdt,
                inToken: usdt,
                fromChain: .tron,
                toChain: .tron,
                tronResource: MultichainTronResource(energy: 64285, bandwidth: 345),
                feeType: .battery,
                batteryCharges: 0
            )
        )

        guard case let .fee(_, amount, _) = try XCTUnwrap(feeRow(in: model)) else {
            return XCTFail("Expected fee row")
        }
        XCTAssertEqual(amount, "0 \(TKLocales.Battery.Refill.chargesCount(count: 0))")
    }

    func test_transactionDetails_batteryFeeTypeWithoutChargesFallsBackToTronResource() throws {
        let usdt = asset(
            symbol: "USDT",
            decimals: 6,
            assetId: "tron/mainnet/trc20/usdt"
        )
        let model = makeDetailsBuilder().build(
            activity: activity(
                id: "tron-send",
                activityType: .send,
                outToken: usdt,
                inToken: usdt,
                fromChain: .tron,
                toChain: .tron,
                tronResource: MultichainTronResource(energy: 64285, bandwidth: 0),
                feeType: .battery,
                batteryCharges: nil
            )
        )

        guard case let .fee(_, amount, _) = try XCTUnwrap(feeRow(in: model)) else {
            return XCTFail("Expected fee row")
        }
        XCTAssertEqual(amount, TKLocales.EventDetails.tronResourceEnergy(grouped(64285)))
    }

    func test_transactionDetails_incomingIgnoresBatteryCharges() throws {
        let usdt = asset(
            symbol: "USDT",
            decimals: 6,
            assetId: "tron/mainnet/trc20/usdt"
        )
        let trx = asset(
            symbol: "TRX",
            decimals: 6,
            assetId: "tron/mainnet/trx"
        )
        let model = makeDetailsBuilder().build(
            activity: activity(
                id: "tron-receive",
                activityType: .receive,
                outToken: usdt,
                inToken: usdt,
                feeToken: trx,
                feeAmount: "1000000",
                fromChain: .tron,
                toChain: .tron,
                feeType: .battery,
                batteryCharges: 2
            )
        )

        guard case let .fee(_, amount, _) = try XCTUnwrap(feeRow(in: model)) else {
            return XCTFail("Expected fee row")
        }
        XCTAssertEqual(amount, "1 TRX")
    }

    func test_transactionDetails_incomingIgnoresTronResourceFee() {
        let usdt = asset(
            symbol: "USDT",
            decimals: 6,
            assetId: "tron/mainnet/trc20/usdt"
        )
        let model = makeDetailsBuilder().build(
            activity: activity(
                id: "tron-receive",
                activityType: .receive,
                outToken: usdt,
                inToken: usdt,
                fromChain: .tron,
                toChain: .tron,
                tronResource: MultichainTronResource(energy: 64285, bandwidth: 345)
            )
        )

        XCTAssertNil(feeRow(in: model))
    }

    func test_transactionDetails_showsTxHashRowBelowFeeRow() throws {
        let eth = asset(
            symbol: "ETH",
            assetId: "eth/mainnet/eth"
        )
        let model = makeDetailsBuilder().build(
            activity: activity(
                id: "eth-send",
                activityType: .send,
                feeToken: eth,
                feeAmount: "1000000000000000000",
                txIds: ["0x19e105318cde"]
            )
        )

        let feeIndex = try XCTUnwrap(feeRowIndex(in: model))
        guard case let .txHash(title, hash) = try XCTUnwrap(model.rows[safe: feeIndex + 1]) else {
            return XCTFail("Expected a tx hash row below the fee row, got \(model.rows)")
        }
        XCTAssertEqual(title, TKLocales.EventDetails.txHash)
        XCTAssertEqual(hash, "0x19e105318cde")
    }

    func test_transactionDetails_txHashRowUsesSourceChainTransactionID() throws {
        let model = makeDetailsBuilder().build(
            activity: activity(
                id: "ignored",
                fromChain: .eth,
                toChain: .ton,
                txIds: ["ton:target-hash", "eth:source-hash"]
            )
        )

        guard case let .txHash(_, hash) = try XCTUnwrap(txHashRow(in: model)) else {
            return XCTFail("Expected a tx hash row, got \(model.rows)")
        }
        XCTAssertEqual(hash, "source-hash")
    }

    func test_transactionDetails_hidesTxHashRowWhenTxIdsAreMissing() {
        let builder = makeDetailsBuilder()

        for txIds in [[], [""], ["eth:"]] {
            let model = builder.build(
                activity: activity(id: "no-hash", txIds: txIds)
            )
            XCTAssertNil(txHashRow(in: model), "Unexpected tx hash row for txIds \(txIds)")
        }
    }

    func test_transactionDetails_sendPreservesNetworkPath() throws {
        let model = makeDetailsBuilder().build(
            activity: activity(
                id: "eth-to-ton-send",
                activityType: .send,
                fromChain: .eth,
                toChain: .ton
            )
        )

        guard case let .network(_, _, type) = try XCTUnwrap(networkRow(in: model)) else {
            return XCTFail("Expected network row")
        }
        XCTAssertEqual(type, "ETH \u{2192} TON")
    }

    func test_transactionDetails_receivePreservesNetworkPath() throws {
        let model = makeDetailsBuilder().build(
            activity: activity(
                id: "eth-to-ton-receive",
                activityType: .receive,
                fromChain: .eth,
                toChain: .ton
            )
        )

        guard case let .network(_, _, type) = try XCTUnwrap(networkRow(in: model)) else {
            return XCTFail("Expected network row")
        }
        XCTAssertEqual(type, "ETH \u{2192} TON")
    }

    @MainActor
    func test_transactionDetails_usesBackendExplorerURLWithoutBrowserTitle() throws {
        let model = makeViewModel(
            multichainService: MultichainServiceSpy()
        ).transactionDetailsModel(
            for: activity(
                id: "ignored",
                txIds: ["ton:target-hash", "eth:source-hash"],
                explorerURL: URL(string: "https://metadata.example/tx/source-hash")
            )
        )

        let button = try XCTUnwrap(model.transactionButton)
        XCTAssertEqual(button.url, URL(string: "https://metadata.example/tx/source-hash"))
        XCTAssertNil(button.browserTitle)
        XCTAssertEqual(button.title.spans.last?.text, "source-h")
    }

    @MainActor
    func test_transactionDetails_hidesTransactionButtonWhenTxIdsAreMissing() {
        let viewModel = makeViewModel(multichainService: MultichainServiceSpy())

        let missing = viewModel.transactionDetailsModel(
            for: activity(
                id: "missing",
                txIds: [],
                explorerURL: URL(string: "https://metadata.example/tx/missing")
            )
        )
        XCTAssertNil(
            missing.transactionButton
        )
        let empty = viewModel.transactionDetailsModel(
            for: activity(
                id: "empty",
                txIds: [""],
                explorerURL: URL(string: "https://metadata.example/tx/empty")
            )
        )
        XCTAssertNil(
            empty.transactionButton
        )
        let prefixOnly = viewModel.transactionDetailsModel(
            for: activity(
                id: "prefix-only",
                txIds: ["eth:"],
                explorerURL: URL(string: "https://metadata.example/tx/prefix-only")
            )
        )
        XCTAssertNil(
            prefixOnly.transactionButton
        )
    }

    @MainActor
    func test_transactionDetails_hidesTransactionButtonWithoutBackendExplorerURL() {
        let model = makeViewModel(
            multichainService: MultichainServiceSpy()
        ).transactionDetailsModel(
            for: activity(
                id: "cross-chain-hash",
                fromChain: .eth,
                toChain: .ton
            )
        )

        XCTAssertNil(model.transactionButton)
    }

    @MainActor
    func test_transactionDetails_prefersBackendExplorerURLForCrossChainActivity() throws {
        let model = makeViewModel(
            multichainService: MultichainServiceSpy()
        ).transactionDetailsModel(
            for: activity(
                id: "eth:source-hash",
                fromChain: .eth,
                toChain: .ton,
                explorerURL: URL(string: "https://bridge.example/tx/source-hash")
            )
        )

        let button = try XCTUnwrap(model.transactionButton)
        XCTAssertEqual(button.url, URL(string: "https://bridge.example/tx/source-hash"))
        XCTAssertNil(button.browserTitle)
    }

    @MainActor
    func test_transactionDetails_hidesTransactionButtonForUnsafeBackendExplorerURL() {
        let model = makeViewModel(
            multichainService: MultichainServiceSpy()
        ).transactionDetailsModel(
            for: activity(
                id: "eth:local-hash",
                explorerURL: URL(string: "javascript:alert(1)")
            )
        )

        XCTAssertNil(model.transactionButton)
    }

    @MainActor
    func test_categoryViewModel_mapsNetworkAndTypeToAPIRequest() async throws {
        let service = MultichainServiceSpy()
        await service.setActivityPlans([
            .success(page(activities: [activity(id: "eth-send")], nextCursor: nil)),
        ])
        let viewModel = makeViewModel(multichainService: service)
        let category = MultichainHistoryCategory.chain(
            chainFilter: .chain(.eth),
            typeFilter: .send
        )
        let queryViewModel = viewModel.contentViewModel(for: category)

        queryViewModel.appeared()

        await waitUntil {
            await service.activityRequests().count == 1
        }

        let requests = await service.activityRequests()
        let request = try XCTUnwrap(requests.first)
        XCTAssertEqual(request.chain, .eth)
        XCTAssertNil(request.assetId)
        XCTAssertEqual(request.activityTypeFilter, .send)
    }

    @MainActor
    func test_categoryViewModel_mapsAssetToAssetIdAPIRequest() async throws {
        let service = MultichainServiceSpy()
        await service.setActivityPlans([
            .success(page(activities: [activity(id: "eth-send")], nextCursor: nil)),
        ])
        let viewModel = makeViewModel(multichainService: service)
        let category = MultichainHistoryCategory.asset(
            assetId: "eth/mainnet/erc20/usdt",
            typeFilter: .send
        )
        let queryViewModel = viewModel.contentViewModel(for: category)

        queryViewModel.appeared()

        await waitUntil {
            await service.activityRequests().count == 1
        }

        let requests = await service.activityRequests()
        let request = try XCTUnwrap(requests.first)
        XCTAssertEqual(request.assetId, "eth/mainnet/erc20/usdt")
        XCTAssertNil(request.chain)
        XCTAssertEqual(request.activityTypeFilter, .send)
    }

    @MainActor
    func test_activityAmounts_areFormattedUsingTokenDecimals() async {
        let eth = asset(
            symbol: "ETH",
            decimals: 18,
            assetId: "eth/mainnet/eth"
        )
        let usdt = asset(
            symbol: "USDT",
            decimals: 6,
            assetId: "eth/mainnet/erc20/usdt"
        )
        let btc = asset(
            symbol: "BTC",
            decimals: 8,
            assetId: "btc/mainnet/btc"
        )
        let service = MultichainServiceSpy()
        await service.setActivityPlans([
            .success(
                page(
                    activities: [
                        activity(
                            id: "send",
                            activityType: .send,
                            amount: "1234567890000000000",
                            outToken: eth,
                            inToken: eth
                        ),
                        activity(
                            id: "receive",
                            activityType: .receive,
                            amount: "1234567",
                            outToken: usdt,
                            inToken: usdt
                        ),
                        activity(
                            id: "swap",
                            activityType: .swap,
                            outAmount: "2500000",
                            inAmount: "100000000",
                            outToken: usdt,
                            inToken: btc
                        ),
                    ],
                    nextCursor: nil
                )
            ),
        ])
        let queryViewModel = makeQueryViewModel(multichainService: service)

        queryViewModel.appeared()
        await waitUntil {
            await MainActor.run {
                self.currentItems(in: queryViewModel).count == 3
            }
        }

        let items = currentItems(in: queryViewModel)
        XCTAssertEqual(items[0].primaryAmount?.text, "\u{2212} 1.23 ETH")
        XCTAssertNil(items[0].primaryAmount?.chainTitle)
        XCTAssertEqual(items[1].primaryAmount?.text, "+ 1.23 USDT")
        XCTAssertEqual(items[1].primaryAmount?.chainTitle, "ETH")
        XCTAssertEqual(items[2].primaryAmount?.text, "+ 1 BTC")
        XCTAssertNil(items[2].primaryAmount?.chainTitle)
        XCTAssertEqual(items[2].secondaryAmount?.text, "\u{2212} 2.5 USDT")
        XCTAssertEqual(items[2].secondaryAmount?.chainTitle, "ETH")
    }

    @MainActor
    func test_swapNativeTonAmount_usesGramSymbol() async throws {
        let ton = asset(
            symbol: "TON",
            decimals: 9,
            assetId: "ton/mainnet/coin"
        )
        let usdt = asset(
            symbol: "USDT",
            decimals: 6,
            assetId: "ton/mainnet/jetton/usdt"
        )
        let service = MultichainServiceSpy()
        await service.setActivityPlans([
            .success(
                page(
                    activities: [
                        activity(
                            id: "swap",
                            activityType: .swap,
                            outAmount: "2500000",
                            inAmount: "1000000000",
                            outToken: usdt,
                            inToken: ton,
                            fromChain: .ton,
                            toChain: .ton
                        ),
                    ],
                    nextCursor: nil
                )
            ),
        ])
        let queryViewModel = makeQueryViewModel(multichainService: service)

        queryViewModel.appeared()
        await waitUntil {
            await MainActor.run {
                self.currentItems(in: queryViewModel).count == 1
            }
        }

        let item = try XCTUnwrap(currentItems(in: queryViewModel).first)
        XCTAssertEqual(item.primaryAmount?.text, "+ 1 GRAM")
        XCTAssertNil(item.primaryAmount?.chainTitle)
        XCTAssertEqual(item.secondaryAmount?.text, "\u{2212} 2.5 USDT")
        XCTAssertEqual(item.secondaryAmount?.chainTitle, "TON")
    }

    @MainActor
    func test_loadNextPage_mergesActivitiesAndFiltersDuplicateValuesKeepingFirstOccurrence() async {
        let first = activity(id: "first", amount: "1")
        let duplicate = activity(id: "duplicate", amount: "2")
        let next = activity(id: "next", amount: "3")
        let service = MultichainServiceSpy()
        await service.setActivityPlans([
            .success(page(activities: [first, duplicate], nextCursor: "cursor-2")),
            .success(page(activities: [duplicate, next], nextCursor: nil)),
        ])
        let queryViewModel = makeQueryViewModel(multichainService: service)

        queryViewModel.appeared()
        await waitUntil {
            await MainActor.run {
                self.currentActivities(in: queryViewModel).count == 2
            }
        }

        guard let lastItem = currentItems(in: queryViewModel).last else {
            return XCTFail("Expected loaded item")
        }
        queryViewModel.loadNextPageIfNeeded(currentItem: lastItem)

        await waitUntil {
            await MainActor.run {
                self.currentActivities(in: queryViewModel).count == 3
            }
        }

        let requests = await service.activityRequests()
        XCTAssertEqual(requests.map(\.cursor), [nil, "cursor-2"])
        XCTAssertEqual(
            currentActivities(in: queryViewModel).map(\.txIds),
            [["first"], ["duplicate"], ["next"]]
        )
    }

    @MainActor
    func test_loadNextPage_updatesDuplicateActivityWithFreshPayloadKeepingOriginalPosition() async {
        let first = activity(id: "first", amount: "1")
        let pendingDuplicate = activity(id: "duplicate", status: .pending, amount: "2")
        let confirmedDuplicate = activity(
            id: "duplicate",
            status: .confirmed,
            amount: "2",
            feeAmount: "3"
        )
        let next = activity(id: "next", amount: "4")
        let service = MultichainServiceSpy()
        await service.setActivityPlans([
            .success(page(activities: [first, pendingDuplicate], nextCursor: "cursor-2")),
            .success(page(activities: [confirmedDuplicate, next], nextCursor: nil)),
        ])
        let queryViewModel = makeQueryViewModel(multichainService: service)

        queryViewModel.appeared()
        await waitUntil {
            await MainActor.run {
                self.currentActivities(in: queryViewModel).count == 2
            }
        }

        guard let lastItem = currentItems(in: queryViewModel).last else {
            return XCTFail("Expected loaded item")
        }
        queryViewModel.loadNextPageIfNeeded(currentItem: lastItem)

        await waitUntil {
            await MainActor.run {
                self.currentActivities(in: queryViewModel).count == 3
            }
        }

        let activities = currentActivities(in: queryViewModel)
        XCTAssertEqual(activities.map(\.txIds), [["first"], ["duplicate"], ["next"]])
        XCTAssertEqual(activities[1].status, .confirmed)
        XCTAssertEqual(activities[1].feeAmount, "3")
    }

    @MainActor
    func test_activityID_keepsActivitiesWithSameTxIdsAndDifferentActivityTypes() async {
        let send = activity(id: "send", activityType: .send, amount: "1", txIds: ["shared"])
        let swap = activity(id: "swap", activityType: .swap, amount: "1", txIds: ["shared"])
        let service = MultichainServiceSpy()
        await service.setActivityPlans([
            .success(page(activities: [send, swap], nextCursor: nil)),
        ])
        let queryViewModel = makeQueryViewModel(multichainService: service)

        queryViewModel.appeared()
        await waitUntil {
            await MainActor.run {
                self.currentActivities(in: queryViewModel).count == 2
            }
        }

        let activities = currentActivities(in: queryViewModel)
        XCTAssertEqual(activities.map(\.activityType), [.send, .swap])
        XCTAssertEqual(activities.map(\.txIds), [["shared"], ["shared"]])
    }

    @MainActor
    func test_activityID_keepsActivitiesWithSameTxIdsAndDifferentAssetIDs() async {
        let eth = asset(symbol: "ETH", assetId: "eth/mainnet/native")
        let usdt = asset(symbol: "USDT", assetId: "eth/mainnet/erc20/usdt")
        let first = activity(id: "first", amount: "1", outToken: eth, inToken: eth, txIds: ["shared"])
        let second = activity(id: "second", amount: "1", outToken: usdt, inToken: usdt, txIds: ["shared"])
        let service = MultichainServiceSpy()
        await service.setActivityPlans([
            .success(page(activities: [first, second], nextCursor: nil)),
        ])
        let queryViewModel = makeQueryViewModel(multichainService: service)

        queryViewModel.appeared()
        await waitUntil {
            await MainActor.run {
                self.currentActivities(in: queryViewModel).count == 2
            }
        }

        let activities = currentActivities(in: queryViewModel)
        XCTAssertEqual(activities.map { $0.outToken?.assetId }, ["eth/mainnet/native", "eth/mainnet/erc20/usdt"])
        XCTAssertEqual(activities.map(\.txIds), [["shared"], ["shared"]])
    }

    @MainActor
    func test_activityID_keepsActivitiesWithSameTxIdsAndDifferentDirectionOrAddresses() async {
        let outgoing = activity(
            id: "outgoing",
            amount: "1",
            txIds: ["shared"],
            direction: .outgoing,
            fromAddress: "0xfrom",
            toAddress: "0xto"
        )
        let incoming = activity(
            id: "incoming",
            amount: "1",
            txIds: ["shared"],
            direction: .incoming,
            fromAddress: "0xotherfrom",
            toAddress: "0xotherto"
        )
        let service = MultichainServiceSpy()
        await service.setActivityPlans([
            .success(page(activities: [outgoing, incoming], nextCursor: nil)),
        ])
        let queryViewModel = makeQueryViewModel(multichainService: service)

        queryViewModel.appeared()
        await waitUntil {
            await MainActor.run {
                self.currentActivities(in: queryViewModel).count == 2
            }
        }

        let activities = currentActivities(in: queryViewModel)
        XCTAssertEqual(activities.map(\.direction), [.outgoing, .incoming])
        XCTAssertEqual(activities.map(\.fromAddress), ["0xfrom", "0xotherfrom"])
        XCTAssertEqual(activities.map(\.toAddress), ["0xto", "0xotherto"])
    }

    @MainActor
    func test_activityID_canonicalizesTxIdsOrderAndEmptyValuesForDeduplication() async {
        let first = activity(id: "first", amount: "1", txIds: ["", "eth:b", "eth:a"])
        let duplicate = activity(id: "duplicate", amount: "1", txIds: ["eth:a", "", "eth:b", "eth:a"])
        let service = MultichainServiceSpy()
        await service.setActivityPlans([
            .success(page(activities: [first, duplicate], nextCursor: nil)),
        ])
        let queryViewModel = makeQueryViewModel(multichainService: service)

        queryViewModel.appeared()
        await waitUntil {
            await MainActor.run {
                if case .loaded = queryViewModel.state {
                    return true
                }
                return false
            }
        }

        let items = currentItems(in: queryViewModel)
        XCTAssertEqual(items.count, 1)
        XCTAssertEqual(items.map(\.id.txIds), [["eth:a", "eth:b"]])
    }

    @MainActor
    func test_loadNextPageIfNeeded_ignoresRepeatedTriggerWhilePaginationIsRunning() async {
        let service = MultichainServiceSpy()
        await service.setActivityPlans([
            .success(
                page(
                    activities: (1 ... 6).map { activity(id: "\($0)") },
                    nextCursor: "cursor-2"
                )
            ),
            .success(
                page(
                    activities: [activity(id: "7")],
                    nextCursor: nil
                ),
                delayNanoseconds: 500_000_000
            ),
        ])
        let queryViewModel = makeQueryViewModel(multichainService: service)

        queryViewModel.appeared()
        await waitUntil {
            await MainActor.run {
                self.currentItems(in: queryViewModel).count == 6
            }
        }

        guard let lastItem = currentItems(in: queryViewModel).last else {
            return XCTFail("Expected loaded item")
        }
        queryViewModel.loadNextPageIfNeeded(currentItem: lastItem)
        queryViewModel.loadNextPageIfNeeded(currentItem: lastItem)

        try? await Task.sleep(nanoseconds: 50_000_000)
        let requests = await service.activityRequests()
        XCTAssertEqual(requests.count, 2)

        await waitUntil {
            await MainActor.run {
                self.currentItems(in: queryViewModel).count == 7
            }
        }
    }

    @MainActor
    func test_loadNextPageIfNeeded_ignoresTriggerWhileRefreshIsRunning() async {
        let service = MultichainServiceSpy()
        await service.setActivityPlans([
            .success(
                page(
                    activities: (1 ... 6).map { activity(id: "\($0)") },
                    nextCursor: "cursor-2"
                )
            ),
            .success(
                page(
                    activities: (1 ... 6).map { activity(id: "refresh-\($0)") },
                    nextCursor: "cursor-2"
                ),
                delayNanoseconds: 300_000_000
            ),
            .success(
                page(
                    activities: [activity(id: "7")],
                    nextCursor: nil
                )
            ),
        ])
        let queryViewModel = makeQueryViewModel(multichainService: service)

        queryViewModel.appeared()
        await waitUntil {
            await MainActor.run {
                self.currentItems(in: queryViewModel).count == 6
            }
        }

        guard let lastItem = currentItems(in: queryViewModel).last else {
            return XCTFail("Expected loaded item")
        }

        let refreshTask = Task { @MainActor in
            await queryViewModel.refresh()
        }

        await waitUntil {
            await service.activityRequests().count == 2
        }

        queryViewModel.loadNextPageIfNeeded(currentItem: lastItem)

        try? await Task.sleep(nanoseconds: 50_000_000)
        var requests = await service.activityRequests()
        XCTAssertEqual(requests.map(\.cursor), [nil, nil])

        await refreshTask.value

        guard let refreshedLastItem = currentItems(in: queryViewModel).last else {
            return XCTFail("Expected refreshed item")
        }
        queryViewModel.loadNextPageIfNeeded(currentItem: refreshedLastItem)

        await waitUntil {
            await service.activityRequests().count == 3
        }

        requests = await service.activityRequests()
        XCTAssertEqual(requests.map(\.cursor), [nil, nil, "cursor-2"])
    }

    @MainActor
    func test_paginationCancelIgnoresSuccessAndFailureCallbacks() async {
        let service = MultichainServiceSpy()
        await service.setActivityPlans([
            .success(
                page(activities: [activity(id: "stale-success")], nextCursor: nil),
                delayNanoseconds: 100_000_000,
                ignoresCancellation: true
            ),
            .failure(
                .connectionError,
                delayNanoseconds: 100_000_000,
                ignoresCancellation: true
            ),
        ])
        let paginationViewModel = MultichainHistoryPaginationViewModel(
            multichainState: makeMultichainState(),
            limit: 30,
            category: .chain(chainFilter: .all, typeFilter: .all),
            multichainService: service
        )
        var pages = [MultichainWalletActivitiesPage]()
        var failuresCount = 0

        let successTask = paginationViewModel.start(
            cursor: "success",
            onSuccess: { page in
                pages.append(page)
            },
            onFailure: { _ in
                failuresCount += 1
            }
        )
        paginationViewModel.cancel()
        await successTask.value

        let failureTask = paginationViewModel.start(
            cursor: "failure",
            onSuccess: { page in
                pages.append(page)
            },
            onFailure: { _ in
                failuresCount += 1
            }
        )
        paginationViewModel.cancel()
        await failureTask.value

        XCTAssertTrue(pages.isEmpty)
        XCTAssertEqual(failuresCount, 0)
    }

    @MainActor
    func test_refreshFailure_keepsPreviouslyLoadedActivities() async {
        let loaded = activity(id: "loaded")
        let service = MultichainServiceSpy()
        await service.setActivityPlans([
            .success(page(activities: [loaded], nextCursor: nil)),
            .failure(.connectionError),
        ])
        let queryViewModel = makeQueryViewModel(multichainService: service)

        queryViewModel.appeared()
        await waitUntil {
            await MainActor.run {
                self.currentActivities(in: queryViewModel) == [loaded]
            }
        }

        await queryViewModel.refresh()

        XCTAssertEqual(currentActivities(in: queryViewModel), [loaded])
        XCTAssertEqual(currentErrorMessage(in: queryViewModel), TKLocales.ConnectionStatus.noInternet)
    }

    @MainActor
    func test_apiErrorWithoutMessage_usesBaseErrorPlaceholder() async {
        let service = MultichainServiceSpy()
        await service.setActivityPlans([
            .failure(.apiError(message: nil)),
        ])
        let queryViewModel = makeQueryViewModel(multichainService: service)

        queryViewModel.appeared()

        await waitUntil {
            await MainActor.run {
                if case .failed = queryViewModel.state {
                    return true
                }
                return false
            }
        }

        XCTAssertNil(currentErrorMessage(in: queryViewModel))
        XCTAssertEqual(queryViewModel.presentation.placeholder, .some(.error(nil)))
    }

    @MainActor
    func test_emptyWithDustFilterOn_usesFilteredPlaceholder() async {
        let service = MultichainServiceSpy()
        await service.setActivityPlans([
            .success(page(activities: [], nextCursor: nil)),
        ])
        let queryViewModel = makeQueryViewModel(
            multichainService: service,
            hidesDustTransactions: true
        )

        queryViewModel.appeared()
        await waitUntil {
            await MainActor.run {
                if case .loaded = queryViewModel.state {
                    return true
                }
                return false
            }
        }

        XCTAssertEqual(queryViewModel.presentation.placeholder, .some(.filtered))
    }

    @MainActor
    func test_emptyWithDustFilterOff_usesEmptyPlaceholder() async {
        let service = MultichainServiceSpy()
        await service.setActivityPlans([
            .success(page(activities: [], nextCursor: nil)),
        ])
        let queryViewModel = makeQueryViewModel(multichainService: service)

        queryViewModel.appeared()
        await waitUntil {
            await MainActor.run {
                if case .loaded = queryViewModel.state {
                    return true
                }
                return false
            }
        }

        XCTAssertEqual(queryViewModel.presentation.placeholder, .some(.empty))
    }

    @MainActor
    func test_presentationGroupsActivitiesByRelativeDate() async {
        let currentDate = makeDate(year: 2026, month: 4, day: 29, hour: 12)
        let todayActivity = activity(
            id: "today",
            blockTime: makeDate(year: 2026, month: 4, day: 29, hour: 10)
        )
        let yesterdayActivity = activity(
            id: "yesterday",
            blockTime: makeDate(year: 2026, month: 4, day: 28, hour: 10)
        )
        let service = MultichainServiceSpy()
        await service.setActivityPlans([
            .success(page(activities: [todayActivity, yesterdayActivity], nextCursor: nil)),
        ])
        let queryViewModel = makeQueryViewModel(
            multichainService: service,
            currentDateProvider: { currentDate }
        )

        queryViewModel.appeared()
        await waitUntil {
            await MainActor.run {
                self.currentItems(in: queryViewModel).count == 2
            }
        }

        XCTAssertEqual(
            queryViewModel.presentation.sections.map(\.title),
            [TKLocales.Dates.today, TKLocales.Dates.yesterday]
        )
        XCTAssertEqual(
            queryViewModel.presentation.sections.map { $0.items.map(\.activity.txIds) },
            [[["today"]], [["yesterday"]]]
        )
    }

    @MainActor
    func test_presentationGroupsCurrentMonthByDayAndPastMonthsByMonth() async {
        let currentDate = makeDate(year: 2026, month: 4, day: 29, hour: 12)
        let currentMonthDay = activity(
            id: "april-27",
            blockTime: makeDate(year: 2026, month: 4, day: 27, hour: 10)
        )
        let currentMonthAnotherDay = activity(
            id: "april-15",
            blockTime: makeDate(year: 2026, month: 4, day: 15, hour: 10)
        )
        let pastMonthFirstDay = activity(
            id: "march-15",
            blockTime: makeDate(year: 2026, month: 3, day: 15, hour: 10)
        )
        let pastMonthSecondDay = activity(
            id: "march-10",
            blockTime: makeDate(year: 2026, month: 3, day: 10, hour: 10)
        )
        let pastYearFirstDay = activity(
            id: "december-31",
            blockTime: makeDate(year: 2025, month: 12, day: 31, hour: 10)
        )
        let pastYearSecondDay = activity(
            id: "december-1",
            blockTime: makeDate(year: 2025, month: 12, day: 1, hour: 10)
        )
        let service = MultichainServiceSpy()
        await service.setActivityPlans([
            .success(
                page(
                    activities: [
                        currentMonthDay,
                        currentMonthAnotherDay,
                        pastMonthFirstDay,
                        pastMonthSecondDay,
                        pastYearFirstDay,
                        pastYearSecondDay,
                    ],
                    nextCursor: nil
                )
            ),
        ])
        let queryViewModel = makeQueryViewModel(
            multichainService: service,
            currentDateProvider: { currentDate }
        )

        queryViewModel.appeared()
        await waitUntil {
            await MainActor.run {
                self.currentItems(in: queryViewModel).count == 6
            }
        }

        XCTAssertEqual(
            queryViewModel.presentation.sections.map(\.title),
            ["27 April", "15 April", "March", "December 2025"]
        )
        XCTAssertEqual(
            queryViewModel.presentation.sections.map { $0.items.map(\.activity.txIds) },
            [
                [["april-27"]],
                [["april-15"]],
                [["march-15"], ["march-10"]],
                [["december-31"], ["december-1"]],
            ]
        )
    }

    @MainActor
    func test_stakingActivities_areTitledByActionTypeInsteadOfTransferDirection() async {
        let ton = asset(symbol: "TON", decimals: 9, assetId: "ton/mainnet/coin")
        let liquidToken = asset(
            symbol: "tsTON",
            decimals: 9,
            assetId: "ton/mainnet/jetton/0:bdf3fa8098d129b54b4f73b5bac5d1e1fd91eb054169c3916dfc8ccd536d1000"
        )
        let service = MultichainServiceSpy()
        await service.setActivityPlans([
            .success(
                page(
                    activities: [
                        activity(
                            id: "unstake",
                            activityType: .unstake,
                            amount: "1751771825",
                            outToken: ton,
                            inToken: ton,
                            fromChain: .ton,
                            toChain: .ton,
                            direction: .incoming
                        ),
                        activity(
                            id: "mint",
                            activityType: .mint,
                            amount: "1751929373",
                            outToken: liquidToken,
                            inToken: liquidToken,
                            fromChain: .ton,
                            toChain: .ton,
                            direction: .incoming
                        ),
                        activity(
                            id: "stake",
                            activityType: .stake,
                            amount: "2000000000",
                            outToken: ton,
                            inToken: ton,
                            fromChain: .ton,
                            toChain: .ton,
                            direction: .outgoing
                        ),
                        activity(
                            id: "burn",
                            activityType: .burn,
                            amount: "1751929373",
                            outToken: liquidToken,
                            inToken: liquidToken,
                            fromChain: .ton,
                            toChain: .ton,
                            direction: .outgoing
                        ),
                    ],
                    nextCursor: nil
                )
            ),
        ])
        let queryViewModel = makeQueryViewModel(multichainService: service)

        queryViewModel.appeared()
        await waitUntil {
            await MainActor.run {
                self.currentItems(in: queryViewModel).count == 4
            }
        }

        let items = currentItems(in: queryViewModel)
        XCTAssertEqual(
            items.map(\.title),
            [
                TKLocales.ActionTypes.unstake,
                TKLocales.History.Tab.received,
                TKLocales.ActionTypes.stake,
                TKLocales.ActionTypes.burned,
            ]
        )
        XCTAssertEqual(items[0].primaryAmount?.text, "+ 1.75 GRAM")
        XCTAssertEqual(items[0].primaryAmount?.style, .positive)
        XCTAssertEqual(items[1].primaryAmount?.text, "+ 1.75 tsTON")
        XCTAssertEqual(items[1].primaryAmount?.style, .positive)
        XCTAssertEqual(items[2].primaryAmount?.text, "\u{2212} 2 GRAM")
        XCTAssertEqual(items[2].primaryAmount?.style, .negative)
        XCTAssertEqual(items[3].primaryAmount?.text, "\u{2212} 1.75 tsTON")
        XCTAssertEqual(items[3].primaryAmount?.style, .negative)
        XCTAssertNil(items[2].secondaryAmount)
    }

    @MainActor
    func test_activityWithoutPreferredSide_fallsBackToPopulatedSide() async {
        let service = MultichainServiceSpy()
        await service.setActivityPlans([
            .success(
                page(
                    activities: [
                        liquidUnstakeRequestActivity(id: "unstake"),
                        activityWithExplicitSides(
                            id: "swap-single-sided",
                            activityType: .swap,
                            direction: .incoming,
                            inToken: asset(symbol: "USDT", decimals: 6, assetId: "ton/mainnet/jetton/usdt"),
                            inAmount: "2670000"
                        ),
                    ],
                    nextCursor: nil
                )
            ),
        ])
        let queryViewModel = makeQueryViewModel(multichainService: service)

        queryViewModel.appeared()
        await waitUntil {
            await MainActor.run {
                self.currentItems(in: queryViewModel).count == 2
            }
        }

        let items = currentItems(in: queryViewModel)
        XCTAssertEqual(items[0].title, TKLocales.ActionTypes.unstake)
        XCTAssertEqual(items[0].primaryAmount?.text, "\u{2212} 0.876 tsTON")
        XCTAssertEqual(items[0].primaryAmount?.style, .negative)
        XCTAssertNil(items[0].secondaryAmount)
        XCTAssertEqual(items[1].primaryAmount?.text, "+ 2.67 USDT")
        XCTAssertEqual(items[1].primaryAmount?.style, .positive)
        XCTAssertNil(items[1].secondaryAmount)
    }

    @MainActor
    func test_stakingActivities_useProviderLogosForKnownProtocols() async {
        let service = MultichainServiceSpy()
        await service.setActivityPlans([
            .success(
                page(
                    activities: [
                        activity(
                            id: "liquid-tf",
                            activityType: .stake,
                            protocolName: "liquidTF"
                        ),
                        activity(
                            id: "whales",
                            activityType: .unstake,
                            protocolName: "whales"
                        ),
                        activity(
                            id: "tf",
                            activityType: .stake,
                            protocolName: "tf"
                        ),
                        activity(
                            id: "unknown-provider",
                            activityType: .stake,
                            protocolName: "unknown"
                        ),
                        activity(
                            id: "missing-provider",
                            activityType: .unstake
                        ),
                        activity(
                            id: "swap-provider",
                            activityType: .swap,
                            protocolName: "liquidTF"
                        ),
                    ],
                    nextCursor: nil
                )
            ),
        ])
        let queryViewModel = makeQueryViewModel(multichainService: service)

        queryViewModel.appeared()
        await waitUntil {
            await MainActor.run {
                self.currentItems(in: queryViewModel).count == 6
            }
        }

        let items = currentItems(in: queryViewModel)
        XCTAssertTrue(items[0].icon.isEqual(UIImage.TKUIKit.Icons.Size44.tonStakersLogo))
        XCTAssertTrue(items[1].icon.isEqual(UIImage.TKUIKit.Icons.Size44.tonWhalesLogo))
        XCTAssertTrue(items[2].icon.isEqual(UIImage.TKUIKit.Icons.Size44.tonNominatorsLogo))
        XCTAssertTrue(items[3].icon.isEqual(UIImage.TKUIKit.Icons.Size28.trayArrowUp))
        XCTAssertTrue(items[4].icon.isEqual(UIImage.TKUIKit.Icons.Size28.trayArrowUp))
        XCTAssertTrue(items[5].icon.isEqual(UIImage.TKUIKit.Icons.Size28.swapHorizontalAlternative))
        XCTAssertEqual(items[0].transactionIcon.renderingMode, .original)
        XCTAssertEqual(items[1].transactionIcon.renderingMode, .original)
        XCTAssertEqual(items[2].transactionIcon.renderingMode, .original)
        XCTAssertEqual(items[3].transactionIcon.renderingMode, .template)
        XCTAssertEqual(items[4].transactionIcon.renderingMode, .template)
        XCTAssertEqual(items[5].transactionIcon.renderingMode, .template)
    }

    @MainActor
    func test_stakingProviderLogos_arePreservedForAllTransactionStatuses() async {
        let statuses: [MultichainActivityStatus] = [.confirmed, .pending, .failed, .dropped]
        let service = MultichainServiceSpy()
        await service.setActivityPlans([
            .success(
                page(
                    activities: statuses.map { status in
                        activity(
                            id: status.rawValue,
                            activityType: .stake,
                            status: status,
                            protocolName: "liquidTF"
                        )
                    },
                    nextCursor: nil
                )
            ),
        ])
        let queryViewModel = makeQueryViewModel(multichainService: service)

        queryViewModel.appeared()
        await waitUntil {
            await MainActor.run {
                self.currentItems(in: queryViewModel).count == statuses.count
            }
        }

        let items = currentItems(in: queryViewModel)
        XCTAssertTrue(
            items.allSatisfy {
                $0.transactionIcon.image.isEqual(UIImage.TKUIKit.Icons.Size44.tonStakersLogo)
            }
        )
        XCTAssertTrue(
            items.allSatisfy { $0.transactionIcon.renderingMode == .original }
        )
        XCTAssertEqual(
            items.first { $0.status == .pending }?.transactionIcon.badge,
            .loader
        )
        XCTAssertTrue(
            items
                .filter { $0.status != .pending }
                .allSatisfy { $0.transactionIcon.badge == nil }
        )
    }

    @MainActor
    func test_stakingActivities_useProviderNamesAsSubtitles() async {
        let service = MultichainServiceSpy()
        await service.setActivityPlans([
            .success(
                page(
                    activities: [
                        activity(
                            id: "liquid-tf",
                            activityType: .stake,
                            protocolName: "liquidTF"
                        ),
                        activity(
                            id: "whales",
                            activityType: .unstake,
                            protocolName: "whales"
                        ),
                        activity(
                            id: "tf",
                            activityType: .stake,
                            protocolName: "tf"
                        ),
                        activity(
                            id: "unknown-provider",
                            activityType: .stake,
                            protocolName: "unknown"
                        ),
                        activity(
                            id: "swap-provider",
                            activityType: .swap,
                            protocolName: "liquidTF"
                        ),
                    ],
                    nextCursor: nil
                )
            ),
        ])
        let queryViewModel = makeQueryViewModel(multichainService: service)

        queryViewModel.appeared()
        await waitUntil {
            await MainActor.run {
                self.currentItems(in: queryViewModel).count == 5
            }
        }

        let items = currentItems(in: queryViewModel)
        XCTAssertEqual(items[0].subtitle, "Tonstakers")
        XCTAssertEqual(items[1].subtitle, "TON Whales")
        XCTAssertEqual(items[2].subtitle, "TON Nominators")
        XCTAssertEqual(items[3].subtitle, "0xtoaddress")
        XCTAssertEqual(items[4].subtitle, "0xtoaddress")
    }

    @MainActor
    func test_activityTypesWithoutDedicatedPresentation_keepTransferDirectionTitles() async {
        let service = MultichainServiceSpy()
        await service.setActivityPlans([
            .success(
                page(
                    activities: [
                        activity(id: "claim", activityType: .claim, direction: .incoming),
                        activity(id: "supply", activityType: .supply, direction: .outgoing),
                    ],
                    nextCursor: nil
                )
            ),
        ])
        let queryViewModel = makeQueryViewModel(multichainService: service)

        queryViewModel.appeared()
        await waitUntil {
            await MainActor.run {
                self.currentItems(in: queryViewModel).count == 2
            }
        }

        let items = currentItems(in: queryViewModel)
        XCTAssertEqual(
            items.map(\.title),
            [TKLocales.History.Tab.received, TKLocales.History.Tab.sent]
        )
        XCTAssertEqual(items[0].primaryAmount?.style, .positive)
        XCTAssertEqual(items[1].primaryAmount?.style, .negative)
    }

    @MainActor
    func test_pendingSend_showsSendingTitleUntilTransactionIsInABlock() async {
        let service = MultichainServiceSpy()
        await service.setActivityPlans([
            .success(
                page(
                    activities: [
                        activity(
                            id: "btc-pending",
                            status: .pending,
                            fromChain: .btc,
                            toChain: .btc,
                            direction: .outgoing
                        ),
                        activity(
                            id: "btc-confirmed",
                            status: .confirmed,
                            fromChain: .btc,
                            toChain: .btc,
                            direction: .outgoing
                        ),
                    ],
                    nextCursor: nil
                )
            ),
        ])
        let queryViewModel = makeQueryViewModel(multichainService: service)

        queryViewModel.appeared()
        await waitUntil {
            await MainActor.run {
                self.currentItems(in: queryViewModel).count == 2
            }
        }

        let items = currentItems(in: queryViewModel)
        XCTAssertEqual(
            items.map(\.title),
            [TKLocales.ActionTypes.sending, TKLocales.History.Tab.sent]
        )
        XCTAssertEqual(items[0].transactionIcon.badge, .loader)
        XCTAssertEqual(items[0].primaryAmount?.style, .negative)
    }

    @MainActor
    func test_failedSend_keepsSentTitle() async {
        let service = MultichainServiceSpy()
        await service.setActivityPlans([
            .success(
                page(
                    activities: [
                        activity(
                            id: "btc-failed",
                            status: .failed,
                            fromChain: .btc,
                            toChain: .btc,
                            direction: .outgoing
                        ),
                    ],
                    nextCursor: nil
                )
            ),
        ])
        let queryViewModel = makeQueryViewModel(multichainService: service)

        queryViewModel.appeared()
        await waitUntil {
            await MainActor.run {
                self.currentItems(in: queryViewModel).count == 1
            }
        }

        XCTAssertEqual(currentItems(in: queryViewModel).first?.title, TKLocales.History.Tab.sent)
    }

    func test_transactionDetails_pendingSendKeepsSentOnDateAndShowsSendingStatus() {
        let model = makeDetailsBuilder().build(
            activity: activity(
                id: "btc-pending",
                status: .pending,
                fromChain: .btc,
                toChain: .btc,
                direction: .outgoing
            )
        )

        XCTAssertTrue(model.date.hasPrefix(TKLocales.EventDetails.sentOn("")))
        XCTAssertEqual(model.pendingTitle, TKLocales.ActionTypes.sending)
    }

    func test_transactionDetails_confirmedSendKeepsSentOnDate() {
        let model = makeDetailsBuilder().build(
            activity: activity(
                id: "btc-confirmed",
                status: .confirmed,
                fromChain: .btc,
                toChain: .btc,
                direction: .outgoing
            )
        )

        XCTAssertNil(model.pendingTitle)
        XCTAssertTrue(model.date.hasPrefix(TKLocales.EventDetails.sentOn("")))
    }

    func test_transactionDetails_pendingReceiveShowsReceivingStatus() {
        let model = makeDetailsBuilder().build(
            activity: activity(
                id: "btc-pending-receive",
                activityType: .receive,
                status: .pending,
                fromChain: .btc,
                toChain: .btc,
                direction: .incoming
            )
        )

        XCTAssertTrue(model.date.hasPrefix(TKLocales.EventDetails.receivedOn("")))
        XCTAssertEqual(model.pendingTitle, TKLocales.ActionTypes.receiving)
    }

    func test_presentationKind_pendingTitlesUseProgressiveTense() {
        let expectations: [(MultichainActivityPresentationKind, String)] = [
            (.send, TKLocales.ActionTypes.sending),
            (.outgoingFallback, TKLocales.ActionTypes.sending),
            (.receive, TKLocales.ActionTypes.receiving),
            (.mint, TKLocales.ActionTypes.receiving),
            (.incomingFallback, TKLocales.ActionTypes.receiving),
            (.swap, TKLocales.ActionTypes.swapping),
            (.stake, TKLocales.ActionTypes.staking),
            (.unstake, TKLocales.ActionTypes.unstaking),
            (.burn, TKLocales.ActionTypes.burning),
            (.dnsRenew, TKLocales.ActionTypes.domainRenewing),
        ]

        for (kind, pendingTitle) in expectations {
            XCTAssertEqual(kind.title(isPending: true), pendingTitle)
            XCTAssertEqual(kind.title(isPending: false), kind.title)
        }
    }

    func test_presentationKind_pendingTitleFallsBackToDirectionForUnknownActivityType() {
        let outgoing = MultichainActivityPresentationKind(
            activity: activity(
                id: "unknown-outgoing",
                activityType: .unknown,
                status: .pending,
                direction: .outgoing
            )
        )
        let incoming = MultichainActivityPresentationKind(
            activity: activity(
                id: "unknown-incoming",
                activityType: .unknown,
                status: .pending,
                direction: .incoming
            )
        )

        XCTAssertEqual(outgoing.title(isPending: true), TKLocales.ActionTypes.sending)
        XCTAssertEqual(incoming.title(isPending: true), TKLocales.ActionTypes.receiving)
    }

    @MainActor
    func test_dnsRenew_usesDedicatedPresentation() async throws {
        let service = MultichainServiceSpy()
        await service.setActivityPlans([
            .success(
                page(
                    activities: [
                        activity(
                            id: "dns-renew",
                            activityType: .dnsRenew,
                            feeToken: asset(symbol: "TON", decimals: 9, assetId: "ton/mainnet/coin"),
                            feeAmount: "100000000",
                            fromChain: .ton,
                            toChain: .ton,
                            direction: .outgoing
                        ),
                    ],
                    nextCursor: nil
                )
            ),
        ])
        let queryViewModel = makeQueryViewModel(multichainService: service)

        queryViewModel.appeared()
        await waitUntil {
            await MainActor.run {
                self.currentItems(in: queryViewModel).count == 1
            }
        }

        let item = try XCTUnwrap(currentItems(in: queryViewModel).first)
        XCTAssertEqual(item.title, TKLocales.ActionTypes.domainRenew)
        XCTAssertTrue(item.icon.isEqual(UIImage.TKUIKit.Icons.Size28.renew))
        XCTAssertEqual(
            item.primaryAmount?.text,
            "\u{2212} 0.1 GRAM",
            "a renewal transfers nothing, so the fee stands in as the amount it cost"
        )
        XCTAssertEqual(item.primaryAmount?.style, .negative)
        XCTAssertNil(item.secondaryAmount)
    }

    @MainActor
    func test_dnsRenew_showsRenewedDomainAsComment() async {
        let service = MultichainServiceSpy()
        await service.setActivityPlans([
            .success(
                page(
                    activities: [
                        activity(
                            id: "dns-renew",
                            activityType: .dnsRenew,
                            protocolName: "tonkeepertesttesttest.ton",
                            fromChain: .ton,
                            toChain: .ton,
                            direction: .outgoing
                        ),
                        activity(
                            id: "swap",
                            activityType: .swap,
                            protocolName: "STON.fi",
                            direction: .outgoing
                        ),
                    ],
                    nextCursor: nil
                )
            ),
        ])
        let queryViewModel = makeQueryViewModel(multichainService: service)

        queryViewModel.appeared()
        await waitUntil {
            await MainActor.run {
                self.currentItems(in: queryViewModel).count == 2
            }
        }

        let items = currentItems(in: queryViewModel)
        XCTAssertEqual(items[0].comment, "tonkeepertesttesttest.ton")
        XCTAssertNil(
            items[1].comment,
            "only a domain renewal reads its comment out of the protocol name"
        )
    }

    @MainActor
    func test_dnsRenew_resolvesTheRenewedDomainNFTFromTheRecipientAddress() async throws {
        let nftAddress = try Address.parse(Self.nftAddress)
        let nftService = FakeNFTService()
        nftService.nftsByAddress[nftAddress] = FakeNFTService.makeNFT(
            address: nftAddress,
            name: "tonkeepertesttesttest.ton",
            collectionName: "TON DNS Domains"
        )
        let service = MultichainServiceSpy()
        await service.setActivityPlans([
            .success(
                page(
                    activities: [
                        activity(
                            id: "dns-renew",
                            activityType: .dnsRenew,
                            feeToken: asset(symbol: "TON", decimals: 9, assetId: "ton/mainnet/coin"),
                            feeAmount: "100000000",
                            protocolName: "tonkeepertesttesttest.ton",
                            fromChain: .ton,
                            toChain: .ton,
                            direction: .outgoing,
                            toAddress: nftAddress.toRaw()
                        ),
                    ],
                    nextCursor: nil
                )
            ),
        ])
        let queryViewModel = makeQueryViewModel(
            multichainService: service,
            nftResolver: makeNFTResolver(nftService: nftService)
        )

        queryViewModel.appeared()
        await waitUntil {
            await MainActor.run {
                self.currentItems(in: queryViewModel).first?.nft != nil
            }
        }

        let item = try XCTUnwrap(currentItems(in: queryViewModel).first)
        XCTAssertEqual(nftService.loadedAddresses, [[nftAddress]])
        XCTAssertEqual(item.nft?.name, "tonkeepertesttesttest.ton")
        XCTAssertEqual(item.nft?.collectionName, "TON DNS Domains")
        XCTAssertEqual(
            item.primaryAmount?.text,
            "\u{2212} 0.1 GRAM",
            "the fee stays the amount a renewal cost; the NFT preview does not stand in for it"
        )
        XCTAssertNil(
            item.comment,
            "the NFT preview already names the domain the comment stood in for"
        )
    }

    func test_transactionDetails_dnsRenewHeadlinesTheDomainAndDropsTheProtocolRow() {
        let model = makeDetailsBuilder().build(
            activity: activity(
                id: "dns-renew",
                activityType: .dnsRenew,
                protocolName: "tonkeepertesttesttest.ton",
                fromChain: .ton,
                toChain: .ton,
                direction: .outgoing
            )
        )

        XCTAssertEqual(model.amountLines.map(\.amount), ["tonkeepertesttesttest.ton"])
        XCTAssertNil(model.amountLines.first?.chain)
        XCTAssertNil(model.fiat)

        let protocolTitles = model.rows.compactMap { row -> String? in
            guard case let .property(title, _) = row else { return nil }
            return title
        }
        XCTAssertFalse(
            protocolTitles.contains(TKLocales.EventDetails.protocol),
            "the headline already shows the domain the protocol row would repeat"
        )
    }

    func test_transactionDetails_stakeUsesStakedOnDateAndRecipientAddress() throws {
        let model = makeDetailsBuilder().build(
            activity: activity(
                id: "stake",
                activityType: .stake,
                fromChain: .ton,
                toChain: .ton,
                direction: .outgoing
            )
        )

        XCTAssertTrue(
            model.date.hasPrefix(TKLocales.EventDetails.stakedOn("")),
            "Expected a staked-on date line, got \(model.date)"
        )
        guard case let .address(type, _) = try XCTUnwrap(model.rows.first) else {
            return XCTFail("Expected address row")
        }
        XCTAssertEqual(type, TKLocales.EventDetails.recipientAddress)
    }

    func test_transactionDetails_unstakeUsesUnstakeOnDateAndSenderAddress() throws {
        let model = makeDetailsBuilder().build(
            activity: activity(
                id: "unstake",
                activityType: .unstake,
                fromChain: .ton,
                toChain: .ton,
                direction: .incoming
            )
        )

        XCTAssertTrue(
            model.date.hasPrefix(TKLocales.EventDetails.unstakeOn("")),
            "Expected an unstake-on date line, got \(model.date)"
        )
        guard case let .address(type, _) = try XCTUnwrap(model.rows.first) else {
            return XCTFail("Expected address row")
        }
        XCTAssertEqual(type, TKLocales.EventDetails.senderAddress)
    }

    func test_transactionDetails_dnsRenewUsesRenewedOnDate() {
        let model = makeDetailsBuilder().build(
            activity: activity(
                id: "dns-renew",
                activityType: .dnsRenew,
                fromChain: .ton,
                toChain: .ton,
                direction: .outgoing
            )
        )

        XCTAssertTrue(
            model.date.hasPrefix(TKLocales.EventDetails.renewedOn("")),
            "Expected a renewed-on date line, got \(model.date)"
        )
    }

    func test_transactionDetails_unstakeWithoutIncomingSideShowsOutgoingAmount() throws {
        let model = makeDetailsBuilder().build(
            activity: liquidUnstakeRequestActivity(id: "unstake")
        )

        XCTAssertTrue(
            model.date.hasPrefix(TKLocales.EventDetails.unstakeOn("")),
            "Expected an unstake-on date line, got \(model.date)"
        )
        XCTAssertEqual(model.amountLines.first?.amount, "\u{2212} 0.876208971 tsTON")
        guard case let .address(type, _) = try XCTUnwrap(model.rows.first) else {
            return XCTFail("Expected address row")
        }
        XCTAssertEqual(type, TKLocales.EventDetails.recipientAddress)
    }

    func test_transactionDetails_burnUsesBurnedOnDate() {
        let model = makeDetailsBuilder().build(
            activity: activity(
                id: "burn",
                activityType: .burn,
                direction: .outgoing
            )
        )

        XCTAssertTrue(
            model.date.hasPrefix(TKLocales.EventDetails.burnedOn("")),
            "Expected a burned-on date line, got \(model.date)"
        )
    }

    func test_transactionDetails_protocolRowShowsProviderDisplayName() throws {
        let model = makeDetailsBuilder().build(
            activity: activity(
                id: "stake",
                activityType: .stake,
                protocolName: "liquidTF",
                fromChain: .ton,
                toChain: .ton,
                direction: .outgoing
            )
        )

        guard case let .property(title, value) = try XCTUnwrap(model.rows.last) else {
            return XCTFail("Expected a protocol row, got \(String(describing: model.rows.last))")
        }
        XCTAssertEqual(title, TKLocales.EventDetails.protocol)
        XCTAssertEqual(value, "Tonstakers")
    }

    func test_transactionDetails_protocolRowFallsBackToRawProtocolName() throws {
        let model = makeDetailsBuilder().build(
            activity: activity(
                id: "swap",
                activityType: .swap,
                protocolName: "stonfi"
            )
        )

        guard case let .property(_, value) = try XCTUnwrap(model.rows.last) else {
            return XCTFail("Expected a protocol row, got \(String(describing: model.rows.last))")
        }
        XCTAssertEqual(value, "stonfi")
    }

    func test_transactionDetails_pendingSwapShowsBothLegLogosWithoutIncomingAmount() {
        let model = makeDetailsBuilder().build(activity: pendingSwapActivity(id: "swap"))

        guard case let .swap(left, right) = model.image else {
            return XCTFail("Expected a swap image pair, got \(model.image)")
        }
        guard case let .url(leftURL, _) = left.imageSource,
              case let .url(rightURL, _) = right.imageSource
        else {
            return XCTFail("Expected remote logos for both swap legs")
        }
        XCTAssertEqual(leftURL, URL(string: "https://from.png"))
        XCTAssertEqual(rightURL, URL(string: "https://to.png"))
        XCTAssertEqual(model.amountLines.map(\.amount), ["\u{2212} 1 ETH", "-"])
    }

    func test_transactionDetails_pendingSwapDateDoesNotClaimCompletedSwap() {
        let model = makeDetailsBuilder().build(activity: pendingSwapActivity(id: "swap"))

        XCTAssertFalse(model.date.hasPrefix(TKLocales.EventDetails.swappedOn("")))
        XCTAssertEqual(model.pendingTitle, TKLocales.ActionTypes.swapping)
    }

    func test_transactionDetails_pendingCrossChainBridgeShowsBothLegLogos() {
        let model = makeDetailsBuilder().build(
            activity: pendingSwapActivity(
                id: "bridge",
                activityType: .bridge,
                toChain: .base
            )
        )

        guard case .swap = model.image else {
            return XCTFail("Expected a swap image pair, got \(model.image)")
        }
        XCTAssertFalse(model.date.hasPrefix(TKLocales.EventDetails.swappedOn("")))
        XCTAssertEqual(model.pendingTitle, TKLocales.ActionTypes.swapping)
    }

    func test_transactionDetails_confirmedBridgeDescribesBothLegsAsSwap() {
        let model = makeDetailsBuilder().build(
            activity: pendingSwapActivity(
                id: "bridge",
                activityType: .bridge,
                status: .confirmed,
                inAmount: "2000000",
                toChain: .base
            )
        )

        guard case .swap = model.image else {
            return XCTFail("Expected a swap image pair, got \(model.image)")
        }
        XCTAssertTrue(
            model.date.hasPrefix(TKLocales.EventDetails.swappedOn("")),
            "Expected a swapped-on date line, got \(model.date)"
        )
    }

    func test_transactionDetails_confirmedSwapKeepsSwappedOnDate() {
        let model = makeDetailsBuilder().build(
            activity: pendingSwapActivity(
                id: "swap",
                status: .confirmed,
                inAmount: "2000000"
            )
        )

        XCTAssertTrue(
            model.date.hasPrefix(TKLocales.EventDetails.swappedOn("")),
            "Expected a swapped-on date line, got \(model.date)"
        )
        XCTAssertNil(model.pendingTitle)
    }

    @MainActor
    func test_presentationGroupsNeighbouringTonActivitiesOfSameEvent() async {
        let service = MultichainServiceSpy()
        await service.setActivityPlans([
            .success(
                page(
                    activities: [
                        tonActivity(id: "mint", blockNumber: 94_709_032_000_003),
                        tonActivity(id: "stake", blockNumber: 94_709_032_000_003),
                    ],
                    nextCursor: nil
                )
            ),
        ])
        let queryViewModel = makeQueryViewModel(multichainService: service)

        queryViewModel.appeared()
        await waitUntil {
            await MainActor.run {
                self.currentItems(in: queryViewModel).count == 2
            }
        }

        XCTAssertEqual(groupedTxIds(in: queryViewModel), [[["mint", "stake"]]])
    }

    @MainActor
    func test_presentationStartsNewGroupWhenSameEventKeyRepeatsWithForeignActivityBetween() async {
        let service = MultichainServiceSpy()
        await service.setActivityPlans([
            .success(
                page(
                    activities: [
                        tonActivity(id: "first", blockNumber: 1),
                        tonActivity(id: "between", blockNumber: 2),
                        tonActivity(id: "last", blockNumber: 1),
                    ],
                    nextCursor: nil
                )
            ),
        ])
        let queryViewModel = makeQueryViewModel(multichainService: service)

        queryViewModel.appeared()
        await waitUntil {
            await MainActor.run {
                self.currentItems(in: queryViewModel).count == 3
            }
        }

        XCTAssertEqual(
            groupedTxIds(in: queryViewModel),
            [[["first"], ["between"], ["last"]]]
        )
    }

    @MainActor
    func test_presentationDoesNotGroupTonActivitiesWithoutBlockNumber() async {
        let service = MultichainServiceSpy()
        await service.setActivityPlans([
            .success(
                page(
                    activities: [
                        tonActivity(id: "first", blockNumber: nil),
                        tonActivity(id: "second", blockNumber: nil),
                    ],
                    nextCursor: nil
                )
            ),
        ])
        let queryViewModel = makeQueryViewModel(multichainService: service)

        queryViewModel.appeared()
        await waitUntil {
            await MainActor.run {
                self.currentItems(in: queryViewModel).count == 2
            }
        }

        XCTAssertEqual(groupedTxIds(in: queryViewModel), [[["first"], ["second"]]])
    }

    @MainActor
    func test_presentationDoesNotGroupNonTonActivitiesSharingBlockNumber() async {
        let service = MultichainServiceSpy()
        await service.setActivityPlans([
            .success(
                page(
                    activities: [
                        activity(id: "first", blockNumber: 25_685_275),
                        activity(id: "second", blockNumber: 25_685_275),
                    ],
                    nextCursor: nil
                )
            ),
        ])
        let queryViewModel = makeQueryViewModel(multichainService: service)

        queryViewModel.appeared()
        await waitUntil {
            await MainActor.run {
                self.currentItems(in: queryViewModel).count == 2
            }
        }

        XCTAssertEqual(groupedTxIds(in: queryViewModel), [[["first"], ["second"]]])
    }

    @MainActor
    func test_presentationDoesNotGroupTonActivitiesOfDifferentWalletAddresses() async {
        let service = MultichainServiceSpy()
        await service.setActivityPlans([
            .success(
                page(
                    activities: [
                        tonActivity(id: "first", blockNumber: 1, walletAddress: "0:first"),
                        tonActivity(id: "second", blockNumber: 1, walletAddress: "0:second"),
                    ],
                    nextCursor: nil
                )
            ),
        ])
        let queryViewModel = makeQueryViewModel(multichainService: service)

        queryViewModel.appeared()
        await waitUntil {
            await MainActor.run {
                self.currentItems(in: queryViewModel).count == 2
            }
        }

        XCTAssertEqual(groupedTxIds(in: queryViewModel), [[["first"], ["second"]]])
    }

    @MainActor
    func test_presentationDoesNotGroupSameEventKeyAcrossDateSections() async {
        let currentDate = makeDate(year: 2026, month: 4, day: 29, hour: 12)
        let service = MultichainServiceSpy()
        await service.setActivityPlans([
            .success(
                page(
                    activities: [
                        tonActivity(
                            id: "today",
                            blockNumber: 1,
                            blockTime: makeDate(year: 2026, month: 4, day: 29, hour: 10)
                        ),
                        tonActivity(
                            id: "yesterday",
                            blockNumber: 1,
                            blockTime: makeDate(year: 2026, month: 4, day: 28, hour: 10)
                        ),
                    ],
                    nextCursor: nil
                )
            ),
        ])
        let queryViewModel = makeQueryViewModel(
            multichainService: service,
            currentDateProvider: { currentDate }
        )

        queryViewModel.appeared()
        await waitUntil {
            await MainActor.run {
                self.currentItems(in: queryViewModel).count == 2
            }
        }

        XCTAssertEqual(groupedTxIds(in: queryViewModel), [[["today"]], [["yesterday"]]])
    }

    @MainActor
    func test_presentationGroupsSameEventKeySplitAcrossPages() async {
        let service = MultichainServiceSpy()
        await service.setActivityPlans([
            .success(
                page(
                    activities: [
                        tonActivity(id: "head", blockNumber: nil),
                        tonActivity(id: "stake", blockNumber: 1),
                    ],
                    nextCursor: "cursor-2"
                )
            ),
            .success(
                page(
                    activities: [
                        tonActivity(id: "mint", blockNumber: 1),
                        tonActivity(id: "tail", blockNumber: nil),
                    ],
                    nextCursor: nil
                )
            ),
        ])
        let queryViewModel = makeQueryViewModel(multichainService: service)

        queryViewModel.appeared()
        await waitUntil {
            await MainActor.run {
                self.currentItems(in: queryViewModel).count == 2
            }
        }

        guard let lastItem = currentItems(in: queryViewModel).last else {
            return XCTFail("Expected loaded item")
        }
        queryViewModel.loadNextPageIfNeeded(currentItem: lastItem)

        await waitUntil {
            await MainActor.run {
                self.currentItems(in: queryViewModel).count == 4
            }
        }

        XCTAssertEqual(
            groupedTxIds(in: queryViewModel),
            [[["head"], ["stake", "mint"], ["tail"]]]
        )
    }

    @MainActor
    func test_receivedTonNFT_replacesTokenAmountWithResolvedNFTPreview() async throws {
        let nftAddress = try Address.parse(Self.nftAddress)
        let nftService = FakeNFTService()
        nftService.nftsByAddress[nftAddress] = FakeNFTService.makeNFT(address: nftAddress)
        let service = MultichainServiceSpy()
        await service.setActivityPlans([
            .success(page(activities: [tonNFTActivity(id: "nft-1")], nextCursor: nil)),
        ])
        let queryViewModel = makeQueryViewModel(
            multichainService: service,
            nftResolver: makeNFTResolver(nftService: nftService)
        )

        queryViewModel.appeared()
        await waitUntil {
            await MainActor.run {
                self.currentItems(in: queryViewModel).first?.nft != nil
            }
        }

        let item = try XCTUnwrap(currentItems(in: queryViewModel).first)
        XCTAssertEqual(item.nft?.name, "Chest #355937")
        XCTAssertEqual(item.nft?.collectionName, "CheQUEs Chests: The Purge")
        XCTAssertEqual(item.nft?.isVerified, true)
        XCTAssertEqual(
            item.nft?.imageURL,
            URL(string: "https://cache.tonapi.io/nft/preview500.png")
        )
        XCTAssertEqual(item.primaryAmount?.text, "NFT")
        XCTAssertNil(item.primaryAmount?.chainTitle)
        XCTAssertNil(item.secondaryAmount)
        XCTAssertEqual(nftService.loadedAddresses, [[nftAddress]])
    }

    @MainActor
    func test_unverifiedTonNFT_usesUnverifiedCollectionName() async throws {
        let nftAddress = try Address.parse(Self.nftAddress)
        let nftService = FakeNFTService()
        nftService.nftsByAddress[nftAddress] = FakeNFTService.makeNFT(
            address: nftAddress,
            trust: .none
        )
        let service = MultichainServiceSpy()
        await service.setActivityPlans([
            .success(page(activities: [tonNFTActivity(id: "nft-1")], nextCursor: nil)),
        ])
        let queryViewModel = makeQueryViewModel(
            multichainService: service,
            nftResolver: makeNFTResolver(nftService: nftService)
        )

        queryViewModel.appeared()
        await waitUntil {
            await MainActor.run {
                self.currentItems(in: queryViewModel).first?.nft != nil
            }
        }

        let item = try XCTUnwrap(currentItems(in: queryViewModel).first)
        XCTAssertEqual(item.nft?.collectionName, TKLocales.NftDetails.unverifiedNft)
        XCTAssertEqual(item.nft?.isVerified, false)
    }

    @MainActor
    func test_blacklistedTonNFT_keepsTokenRendering() async throws {
        let nftAddress = try Address.parse(Self.nftAddress)
        let nftService = FakeNFTService()
        nftService.nftsByAddress[nftAddress] = FakeNFTService.makeNFT(
            address: nftAddress,
            trust: .blacklist
        )
        let service = MultichainServiceSpy()
        await service.setActivityPlans([
            .success(page(activities: [tonNFTActivity(id: "nft-1")], nextCursor: nil)),
        ])
        let queryViewModel = makeQueryViewModel(
            multichainService: service,
            nftResolver: makeNFTResolver(nftService: nftService)
        )

        queryViewModel.appeared()
        await waitUntil {
            await MainActor.run {
                !nftService.loadedAddresses.isEmpty
            }
        }

        let item = try XCTUnwrap(currentItems(in: queryViewModel).first)
        XCTAssertNil(item.nft)
        XCTAssertNotEqual(item.primaryAmount?.text, "NFT")
    }

    @MainActor
    func test_jettonActivity_doesNotTriggerNFTResolution() async throws {
        let nftService = FakeNFTService()
        let service = MultichainServiceSpy()
        await service.setActivityPlans([
            .success(
                page(
                    activities: [
                        tonNFTActivity(
                            id: "jetton-1",
                            assetId: "ton/mainnet/jetton/\(Self.nftAddress)"
                        ),
                    ],
                    nextCursor: nil
                )
            ),
        ])
        let queryViewModel = makeQueryViewModel(
            multichainService: service,
            nftResolver: makeNFTResolver(nftService: nftService)
        )

        queryViewModel.appeared()
        await waitUntil {
            await MainActor.run {
                self.currentItems(in: queryViewModel).count == 1
            }
        }

        let item = try XCTUnwrap(currentItems(in: queryViewModel).first)
        XCTAssertNil(item.nft)
        XCTAssertTrue(nftService.loadedAddresses.isEmpty)
    }

    @MainActor
    func test_spamActivity_doesNotTriggerNFTResolution() async throws {
        let nftService = FakeNFTService()
        let service = MultichainServiceSpy()
        await service.setActivityPlans([
            .success(
                page(
                    activities: [tonNFTActivity(id: "nft-spam", isSpam: true)],
                    nextCursor: nil
                )
            ),
        ])
        let queryViewModel = makeQueryViewModel(
            multichainService: service,
            category: .chain(chainFilter: .all, typeFilter: .spam),
            nftResolver: makeNFTResolver(nftService: nftService)
        )

        queryViewModel.appeared()
        await waitUntil {
            await MainActor.run {
                self.currentItems(in: queryViewModel).count == 1
            }
        }

        let item = try XCTUnwrap(currentItems(in: queryViewModel).first)
        XCTAssertNil(item.nft)
        XCTAssertTrue(nftService.loadedAddresses.isEmpty)
    }

    @MainActor
    func test_alreadyResolvedNFT_isNotRequestedAgainOnRefresh() async throws {
        let nftAddress = try Address.parse(Self.nftAddress)
        let nftService = FakeNFTService()
        nftService.nftsByAddress[nftAddress] = FakeNFTService.makeNFT(address: nftAddress)
        let service = MultichainServiceSpy()
        await service.setActivityPlans([
            .success(page(activities: [tonNFTActivity(id: "nft-1")], nextCursor: nil)),
            .success(page(activities: [tonNFTActivity(id: "nft-1")], nextCursor: nil)),
        ])
        let queryViewModel = makeQueryViewModel(
            multichainService: service,
            nftResolver: makeNFTResolver(nftService: nftService)
        )

        queryViewModel.appeared()
        await waitUntil {
            await MainActor.run {
                self.currentItems(in: queryViewModel).first?.nft != nil
            }
        }

        await queryViewModel.refresh()
        await waitUntil {
            await MainActor.run {
                self.currentItems(in: queryViewModel).first?.nft != nil
            }
        }

        XCTAssertEqual(nftService.loadedAddresses, [[nftAddress]])
    }

    @MainActor
    func test_nftResolution_leavesUnaffectedCategoryStateUntouched() async throws {
        let nftAddress = try Address.parse(Self.nftAddress)
        let nftService = FakeNFTService()
        nftService.nftsByAddress[nftAddress] = FakeNFTService.makeNFT(address: nftAddress)
        let nftResolver = makeNFTResolver(nftService: nftService)

        let service = MultichainServiceSpy()
        await service.setActivityPlans([
            .success(
                page(
                    activities: [
                        tonNFTActivity(
                            id: "jetton-1",
                            assetId: "ton/mainnet/jetton/\(Self.nftAddress)"
                        ),
                    ],
                    nextCursor: nil
                )
            ),
        ])
        let queryViewModel = makeQueryViewModel(
            multichainService: service,
            nftResolver: nftResolver
        )

        queryViewModel.appeared()
        await waitUntil {
            await MainActor.run {
                self.currentItems(in: queryViewModel).count == 1
            }
        }

        var stateUpdates = 0
        let observation = queryViewModel.$state
            .dropFirst()
            .sink { _ in
                stateUpdates += 1
            }
        defer { observation.cancel() }

        await nftResolver.resolve(activities: [tonNFTActivity(id: "nft-1")])

        XCTAssertEqual(stateUpdates, 0)
        XCTAssertNil(currentItems(in: queryViewModel).first?.nft)
    }

    func test_detailsModelForNFT_showsNFTHeaderWithoutTokenAmount() {
        let nft = MultichainActivityNFT(
            id: "nft",
            name: "Chest #355937",
            collectionName: "CheQUEs Chests: The Purge",
            imageURL: URL(string: "https://cache.tonapi.io/nft/preview500.png"),
            isVerified: true
        )
        let model = makeDetailsBuilder(nftProvider: { _ in nft })
            .build(activity: tonNFTActivity(id: "nft-1"))

        guard case .nft = model.image else {
            return XCTFail("expected nft image")
        }
        XCTAssertEqual(model.amountLines.map(\.amount), ["NFT"])
        XCTAssertNil(model.amountLines.first?.chain)
        XCTAssertNil(model.fiat)
        XCTAssertEqual(model.nft?.name, "Chest #355937")
        XCTAssertEqual(model.nft?.collectionName, "CheQUEs Chests: The Purge")
        XCTAssertEqual(model.nft?.isVerified, true)
    }
}

private extension MultichainHistoryViewModelTests {
    @MainActor
    func makeViewModel(
        multichainService: MultichainService,
        hidesDustTransactions: Bool = false,
        isPerpsEnabled: Bool = false,
        nftResolver: MultichainActivityNFTResolver? = nil,
        currentDateProvider: @escaping () -> Date = Date.init,
        addresses: [MultichainWalletAddress]? = nil,
        onAddFunds: @escaping () -> Void = {}
    ) -> MultichainHistoryViewModelImplementation {
        MultichainHistoryViewModelImplementation(
            multichainState: makeMultichainState(addresses: addresses),
            hidesDustTransactions: hidesDustTransactions,
            isPerpsEnabled: isPerpsEnabled,
            multichainService: multichainService,
            amountFormatter: makeAmountFormatter(),
            dateFormatter: makeDateFormatter(),
            nftResolver: nftResolver ?? makeNFTResolver(),
            currentDateProvider: currentDateProvider,
            chainImageProvider: { _ in nil },
            onAddFunds: onAddFunds
        )
    }

    @MainActor
    func makeQueryViewModel(
        multichainService: MultichainService,
        category: MultichainHistoryCategory = .chain(chainFilter: .all, typeFilter: .all),
        hidesDustTransactions: Bool = false,
        nftResolver: MultichainActivityNFTResolver? = nil,
        currentDateProvider: @escaping () -> Date = Date.init
    ) -> MultichainHistoryQueryViewModel {
        MultichainHistoryQueryViewModel(
            multichainState: makeMultichainState(),
            category: category,
            hidesDustTransactions: hidesDustTransactions,
            multichainService: multichainService,
            amountFormatter: makeAmountFormatter(),
            dateFormatter: makeDateFormatter(),
            nftResolver: nftResolver ?? makeNFTResolver(),
            currentDateProvider: currentDateProvider
        )
    }

    func makeDetailsBuilder(
        nftProvider: @escaping (MultichainActivity) -> MultichainActivityNFT? = { _ in nil }
    ) -> MultichainTransactionDetailsModelBuilder {
        MultichainTransactionDetailsModelBuilder(
            amountFormatter: makeAmountFormatter(),
            dateFormatter: makeDateFormatter(),
            transactionButtonProvider: { _ in nil },
            nftProvider: nftProvider
        )
    }

    @MainActor
    func makeNFTResolver(
        nftService: NFTService = FakeNFTService()
    ) -> MultichainActivityNFTResolver {
        MultichainActivityNFTResolver(
            nftService: nftService,
            network: .mainnet
        )
    }

    func makeMultichainState(addresses: [MultichainWalletAddress]? = nil) -> MultichainWalletState {
        MultichainWalletState(
            walletId: "wallet",
            addresses: addresses ?? [
                MultichainWalletAddress(chain: .eth, address: "0xwallet"),
                MultichainWalletAddress(chain: .btc, address: "bc1wallet"),
            ]
        )
    }

    func makeAmountFormatter() -> AmountFormatter {
        var configuration = AmountFormatter.Configuration()
        configuration.locale = Locale(identifier: "en_US_POSIX")
        configuration.space = " "
        return AmountFormatter(configuration: configuration)
    }

    func makeDateFormatter() -> DateFormatter {
        let dateFormatter = DateFormatter()
        dateFormatter.locale = Locale(identifier: "en_US_POSIX")
        dateFormatter.timeZone = TimeZone(secondsFromGMT: 0)
        return dateFormatter
    }

    func page(
        activities: [MultichainActivity],
        nextCursor: String?
    ) -> MultichainWalletActivitiesPage {
        MultichainWalletActivitiesPage(
            activities: activities,
            nextCursor: nextCursor
        )
    }

    func networkRow(
        in model: MultichainTransactionDetailsModel
    ) -> MultichainTransactionDetailsCellContent? {
        model.rows.first { row in
            if case .network = row {
                return true
            }
            return false
        }
    }

    func feeRowIndex(in model: MultichainTransactionDetailsModel) -> Int? {
        model.rows.firstIndex { row in
            if case .fee = row {
                return true
            }
            return false
        }
    }

    func feeRow(
        in model: MultichainTransactionDetailsModel
    ) -> MultichainTransactionDetailsCellContent? {
        feeRowIndex(in: model).map { model.rows[$0] }
    }

    func grouped(_ value: Int64) -> String {
        let formatter = NumberFormatter()
        formatter.locale = .current
        formatter.numberStyle = .decimal
        formatter.usesGroupingSeparator = true
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: value)) ?? "\(value)"
    }

    func txHashRow(
        in model: MultichainTransactionDetailsModel
    ) -> MultichainTransactionDetailsCellContent? {
        model.rows.first { row in
            if case .txHash = row {
                return true
            }
            return false
        }
    }

    func activity(
        id: String,
        activityType: MultichainActivityType = .send,
        status: MultichainActivityStatus = .confirmed,
        amount: String = "1",
        outAmount: String? = nil,
        inAmount: String? = nil,
        outToken: MultichainAssetDetails? = nil,
        inToken: MultichainAssetDetails? = nil,
        feeToken: MultichainAssetDetails? = nil,
        feeAmount: String? = nil,
        feeAmountUsd: Double? = nil,
        protocolName: String? = nil,
        fromChain: MultichainChain = .eth,
        toChain: MultichainChain = .eth,
        txIds: [String]? = nil,
        explorerURL: URL? = nil,
        walletAddress: String? = "0xwallet",
        direction: MultichainActivityDirection? = nil,
        fromAddress: String? = "0xfromaddress",
        toAddress: String? = "0xtoaddress",
        isSpam: Bool = false,
        blockTime: Date = Date(timeIntervalSince1970: 1_777_440_000),
        blockNumber: Int64? = nil,
        tronResource: MultichainTronResource? = nil,
        feeType: MultichainActivityFeeType? = nil,
        batteryCharges: Int? = nil
    ) -> MultichainActivity {
        let defaultToken = asset(symbol: "ETH")
        return MultichainActivity(
            activityType: activityType,
            status: status,
            blockTime: blockTime,
            blockNumber: blockNumber,
            fromChain: fromChain,
            toChain: toChain,
            walletAddress: walletAddress,
            direction: direction ?? (activityType == .receive ? .incoming : .outgoing),
            fromAddress: fromAddress,
            toAddress: toAddress,
            outToken: outToken ?? defaultToken,
            outAmount: outAmount ?? amount,
            outAmountUsd: nil,
            inToken: inToken ?? defaultToken,
            inAmount: inAmount ?? amount,
            inAmountUsd: nil,
            feeToken: feeToken,
            feeAmount: feeAmount,
            feeAmountUsd: feeAmountUsd,
            protocolName: protocolName,
            txIds: txIds ?? [id],
            explorerURL: explorerURL,
            isRead: nil,
            isSpam: isSpam,
            tronResource: tronResource,
            feeType: feeType,
            batteryCharges: batteryCharges
        )
    }

    func activityWithExplicitSides(
        id: String,
        activityType: MultichainActivityType,
        direction: MultichainActivityDirection,
        status: MultichainActivityStatus = .confirmed,
        outToken: MultichainAssetDetails? = nil,
        outAmount: String? = nil,
        inToken: MultichainAssetDetails? = nil,
        inAmount: String? = nil,
        protocolName: String? = nil,
        fromChain: MultichainChain = .ton,
        toChain: MultichainChain = .ton,
        walletAddress: String? = "0:wallet",
        fromAddress: String? = "0:fromaddress",
        toAddress: String? = "0:toaddress",
        blockTime: Date = Date(timeIntervalSince1970: 1_777_440_000)
    ) -> MultichainActivity {
        MultichainActivity(
            activityType: activityType,
            status: status,
            blockTime: blockTime,
            blockNumber: nil,
            fromChain: fromChain,
            toChain: toChain,
            walletAddress: walletAddress,
            direction: direction,
            fromAddress: fromAddress,
            toAddress: toAddress,
            outToken: outToken,
            outAmount: outAmount,
            outAmountUsd: nil,
            inToken: inToken,
            inAmount: inAmount,
            inAmountUsd: nil,
            feeToken: nil,
            feeAmount: nil,
            feeAmountUsd: nil,
            protocolName: protocolName,
            txIds: [id],
            explorerURL: nil,
            isRead: nil
        )
    }

    func pendingSwapActivity(
        id: String,
        activityType: MultichainActivityType = .swap,
        status: MultichainActivityStatus = .pending,
        inAmount: String? = nil,
        toChain: MultichainChain = .eth
    ) -> MultichainActivity {
        activityWithExplicitSides(
            id: id,
            activityType: activityType,
            direction: .outgoing,
            status: status,
            outToken: asset(
                symbol: "ETH",
                assetId: "eth/mainnet/coin",
                image: "https://from.png"
            ),
            outAmount: "1000000000000000000",
            inToken: asset(
                symbol: "USDT",
                decimals: 6,
                assetId: "eth/mainnet/erc20/usdt",
                image: "https://to.png"
            ),
            inAmount: inAmount,
            fromChain: .eth,
            toChain: toChain
        )
    }

    func liquidUnstakeRequestActivity(id: String) -> MultichainActivity {
        activityWithExplicitSides(
            id: id,
            activityType: .unstake,
            direction: .outgoing,
            outToken: asset(
                symbol: "tsTON",
                decimals: 9,
                assetId: "ton/mainnet/jetton/0:bdf3fa8098d129b54b4f73b5bac5d1e1fd91eb054169c3916dfc8ccd536d1000"
            ),
            outAmount: "876208971",
            protocolName: "liquidTF"
        )
    }

    func tonActivity(
        id: String,
        blockNumber: Int64?,
        walletAddress: String? = "0:wallet",
        blockTime: Date = Date(timeIntervalSince1970: 1_777_440_000)
    ) -> MultichainActivity {
        activity(
            id: id,
            fromChain: .ton,
            toChain: .ton,
            walletAddress: walletAddress,
            blockTime: blockTime,
            blockNumber: blockNumber
        )
    }

    @MainActor
    func groupedTxIds(
        in queryViewModel: MultichainHistoryQueryViewModel
    ) -> [[[String]]] {
        queryViewModel.presentation.sections.map { section in
            section.groups.map { group in
                group.items.flatMap(\.activity.txIds)
            }
        }
    }

    static let nftAddress = "EQD2NmD_lH5f5u1Kj3KfGyTvhZSX0Eg6qp2a5IQUKXxOG21n"

    static var nftAssetId: String {
        "ton/mainnet/nft/\(nftAddress)"
    }

    func tonNFTActivity(
        id: String,
        assetId: String = MultichainHistoryViewModelTests.nftAssetId,
        isSpam: Bool = false
    ) -> MultichainActivity {
        activity(
            id: id,
            activityType: .receive,
            inToken: MultichainAssetDetails(
                assetId: assetId,
                name: "NFT",
                symbol: "NFT",
                decimals: 0,
                image: ""
            ),
            fromChain: .ton,
            toChain: .ton,
            isSpam: isSpam
        )
    }

    func asset(
        symbol: String,
        decimals: Int = 18,
        assetId: String? = nil,
        image: String = ""
    ) -> MultichainAssetDetails {
        MultichainAssetDetails(
            assetId: assetId ?? "eth/mainnet/erc20/\(symbol.lowercased())",
            name: symbol,
            symbol: symbol,
            decimals: decimals,
            image: image
        )
    }

    @MainActor
    func currentItems(
        in queryViewModel: MultichainHistoryQueryViewModel?
    ) -> [MultichainHistoryActivityItem] {
        guard let queryViewModel else {
            return []
        }

        switch queryViewModel.state {
        case .idle:
            return []
        case let .loaded(rowData), let .failed(rowData, _), let .refreshing(rowData, _), let .loadingMore(rowData, _):
            return rowData.items
        }
    }

    @MainActor
    func currentActivities(
        in queryViewModel: MultichainHistoryQueryViewModel?
    ) -> [MultichainActivity] {
        currentItems(in: queryViewModel).map(\.activity)
    }

    @MainActor
    func currentErrorMessage(
        in queryViewModel: MultichainHistoryQueryViewModel
    ) -> String? {
        switch queryViewModel.state {
        case let .failed(_, errorMessage):
            return errorMessage
        case .idle, .refreshing, .loaded, .loadingMore:
            return nil
        }
    }

    func makeDate(
        year: Int,
        month: Int,
        day: Int,
        hour: Int
    ) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar.date(
            from: DateComponents(
                timeZone: TimeZone(secondsFromGMT: 0),
                year: year,
                month: month,
                day: day,
                hour: hour
            )
        )!
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

private actor MultichainHistoryTestGate {
    private var didEnter = false
    private var isOpen = false
    private var enterWaiters = [CheckedContinuation<Void, Never>]()
    private var openWaiters = [CheckedContinuation<Void, Never>]()

    func enter() async {
        didEnter = true
        resume(&enterWaiters)

        guard !isOpen else {
            return
        }
        await withCheckedContinuation { openWaiters.append($0) }
    }

    func waitUntilEntered() async {
        guard !didEnter else {
            return
        }
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

private actor MultichainServiceSpy: MultichainService {
    struct ActivityRequest: Equatable {
        let walletId: String
        let limit: Int?
        let cursor: String?
        let chain: MultichainChain?
        let assetId: String?
        let activityTypeFilter: MultichainActivityTypeFilter?
        let showPerps: Bool?
        let hideDust: Bool?
    }

    struct Plan {
        let result: Result<MultichainWalletActivitiesPage, MultichainServiceError>
        let delayNanoseconds: UInt64
        let ignoresCancellation: Bool
        let gate: MultichainHistoryTestGate?

        static func success(
            _ page: MultichainWalletActivitiesPage,
            delayNanoseconds: UInt64 = 0,
            ignoresCancellation: Bool = false,
            gate: MultichainHistoryTestGate? = nil
        ) -> Plan {
            Plan(
                result: .success(page),
                delayNanoseconds: delayNanoseconds,
                ignoresCancellation: ignoresCancellation,
                gate: gate
            )
        }

        static func failure(
            _ error: MultichainServiceError,
            delayNanoseconds: UInt64 = 0,
            ignoresCancellation: Bool = false
        ) -> Plan {
            Plan(
                result: .failure(error),
                delayNanoseconds: delayNanoseconds,
                ignoresCancellation: ignoresCancellation,
                gate: nil
            )
        }
    }

    private var activityPlanQueue = [Plan]()
    private var recordedActivityRequests = [ActivityRequest]()

    func setActivityPlans(_ plans: [Plan]) {
        activityPlanQueue = plans
    }

    func activityRequests() -> [ActivityRequest] {
        recordedActivityRequests
    }

    func getWalletActivities(
        state: MultichainWalletState,
        limit: Int?,
        cursor: String?,
        chain: MultichainChain?,
        assetId: String?,
        activityTypeFilter: MultichainActivityTypeFilter?,
        showPerps: Bool?,
        hideDust: Bool?
    ) async throws(MultichainServiceError) -> MultichainWalletActivitiesPage {
        recordedActivityRequests.append(
            ActivityRequest(
                walletId: state.walletId,
                limit: limit,
                cursor: cursor,
                chain: chain,
                assetId: assetId,
                activityTypeFilter: activityTypeFilter,
                showPerps: showPerps,
                hideDust: hideDust
            )
        )

        guard !activityPlanQueue.isEmpty else {
            throw .apiError(message: "Missing activity plan")
        }

        let plan = activityPlanQueue.removeFirst()
        if plan.delayNanoseconds > 0 {
            do {
                try await Task.sleep(nanoseconds: plan.delayNanoseconds)
            } catch {
                if !plan.ignoresCancellation {
                    throw .cancelled
                }
            }
        }

        if let gate = plan.gate {
            await gate.enter()
        }

        return try plan.result.get()
    }

    func healthcheck() async throws(MultichainServiceError) -> MultichainHealth {
        throw .apiError(message: "Unimplemented")
    }

    func searchAssets(
        currencies: [String],
        chain: MultichainChain?,
        search: String?,
        sort: MultichainAssetSearchSort,
        limit: Int?,
        cursor: String?
    ) async throws(MultichainServiceError) -> (assets: [MultichainAsset], nextCursor: String?) {
        throw .apiError(message: "Unimplemented")
    }

    func getWallet(walletId: String) async throws(MultichainServiceError) -> MultichainRegisteredWallet {
        throw .apiError(message: "Unimplemented")
    }

    func getWalletSyncStatus(walletId: String) async throws(MultichainServiceError) -> MultichainWalletSyncStatus {
        throw .apiError(message: "Unimplemented")
    }

    func getWalletChallenge() async throws(MultichainServiceError) -> MultichainWalletChallenge {
        throw .apiError(message: "Unimplemented")
    }

    func getWalletAssets(
        state _: MultichainWalletState,
        currencies: [String],
        assetIds: [String]?,
        capabilities _: [MultichainAssetCapability]?,
        chain: MultichainChain?,
        search: String?,
        availableOnly: Bool?,
        showHidden: Bool?,
        hideDust _: Bool?,
        limit: Int?,
        cursor: String?
    ) async throws(MultichainServiceError) -> MultichainWalletAssetsPage {
        throw .apiError(message: "Unimplemented")
    }

    func saveWalletAssetsFilters(walletId: String, changes: [MultichainAssetFilterChange]) async throws(MultichainServiceError) {
        throw .apiError(message: "Unimplemented")
    }

    func registerWallet(walletId: String, addresses: [MultichainWalletAddress]) async throws(MultichainServiceError) -> MultichainRegisteredWallet {
        throw .apiError(message: "Unimplemented")
    }

    func broadcastTx(chain: MultichainChain, signedTransaction: Data) async throws(MultichainServiceError) -> MultichainBroadcastResult {
        throw .apiError(message: "Unimplemented")
    }

    func getFees(chain: MultichainChain) async throws(MultichainServiceError) -> MultichainFeeEstimate {
        throw .apiError(message: "Unimplemented")
    }

    func getWalletRaffles(
        walletId: String,
        lang: String?,
        ids: [String]?,
        debugNow: Date?,
        isNewUser: Bool
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
