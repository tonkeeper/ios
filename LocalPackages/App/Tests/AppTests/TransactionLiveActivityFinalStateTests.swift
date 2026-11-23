@testable import App
import Foundation
import KeeperCore
import PerpsModels
import TKLocalize
import XCTest

@available(iOS 16.2, *)
final class TransactionLiveActivityFinalStateTests: XCTestCase {
    typealias Mock = TransactionLiveActivityMock
    typealias Status = TransactionLiveActivitySnapshot.Status

    func test_everyMockScenarioEndsInItsOwnFinalStateUnderTheSameId() throws {
        let expectations: [Mock.Scenario: (pending: String, status: Status, final: String)] = [
            .sendConfirmed: (TKLocales.ActionTypes.sending, .confirmed, TKLocales.History.Tab.sent),
            .receiveConfirmed: (TKLocales.ActionTypes.receiving, .confirmed, TKLocales.History.Tab.received),
            .swapConfirmed: (TKLocales.ActionTypes.swapping, .confirmed, TKLocales.LiveActivity.swapped),
            .swapFailed: (TKLocales.ActionTypes.swapping, .failed, TKLocales.LiveActivity.swapFailed),
            .bridgeConfirmed: (TKLocales.LiveActivity.Stage.movingTo("TRON"), .confirmed, TKLocales.LiveActivity.swapped),
            .receiveDropped: (TKLocales.ActionTypes.receiving, .dropped, TKLocales.LiveActivity.notReceived),
            .perpsDeposit: (TKLocales.LiveActivity.depositing, .confirmed, TKLocales.LiveActivity.deposited),
            .perpsWithdraw: (TKLocales.LiveActivity.withdrawing, .confirmed, TKLocales.LiveActivity.withdrawn),
            .perpsOpenLong: (
                TKLocales.LiveActivity.openingLong, .confirmed, TKLocales.MultichainHistory.Perps.openedLong
            ),
            .perpsCloseShort: (
                TKLocales.LiveActivity.closingShort, .confirmed, TKLocales.MultichainHistory.Perps.closedShort
            ),
        ]
        let start = Date()
        for scenario in Mock.Scenario.allCases where scenario != .sendPending {
            let expected = try XCTUnwrap(expectations[scenario], "\(scenario)")
            let entry = Mock.Entry(
                id: UUID().uuidString,
                scenario: scenario,
                startedAt: start,
                resolvesAt: start.addingTimeInterval(Mock.resolveDelay)
            )
            let pending = try XCTUnwrap(Mock.snapshot(for: entry, now: start.addingTimeInterval(Mock.resolveDelay - 1)))
            let final = try XCTUnwrap(Mock.snapshot(for: entry, now: start.addingTimeInterval(Mock.resolveDelay)))

            XCTAssertEqual(pending.status, .pending, "\(scenario)")
            XCTAssertEqual(pending.title, expected.pending, "\(scenario)")
            XCTAssertEqual(final.status, expected.status, "\(scenario)")
            XCTAssertEqual(final.title, expected.final, "\(scenario)")
            XCTAssertEqual(
                TransactionLiveActivitySelection.matching(pending.id, in: [final])?.status,
                expected.status,
                "\(scenario)"
            )
            XCTAssertNotNil(TransactionLiveActivitySelection.nextPending(in: [pending]), "\(scenario)")
        }
    }

    func test_stagedMocksWalkThroughTheirStagesUnderTheSameId() throws {
        typealias Stage = TransactionLiveActivitySnapshot.Stage
        let expectations: [Mock.Scenario: (title: String, stages: [Stage])] = [
            .perpsDeposit: (TKLocales.LiveActivity.depositing, [
                Stage(index: 1, count: 3, title: TKLocales.LiveActivity.Stage.sendingFromWallet),
                Stage(index: 2, count: 3, title: TKLocales.LiveActivity.Stage.convertingTo("USDC")),
                Stage(index: 3, count: 3, title: TKLocales.LiveActivity.Stage.convertingTo("USDC")),
            ]),
            .perpsWithdraw: (TKLocales.LiveActivity.withdrawing, [
                Stage(index: 1, count: 3, title: TKLocales.LiveActivity.Stage.sendingRequest),
                Stage(index: 2, count: 3, title: TKLocales.LiveActivity.Stage.processingWithdrawal),
                Stage(index: 3, count: 3, title: TKLocales.LiveActivity.Stage.sendingToWallet),
            ]),
            .bridgeConfirmed: (TKLocales.LiveActivity.Stage.movingTo("TRON"), [
                Stage(index: 2, count: 3, title: TKLocales.LiveActivity.Stage.sending),
                Stage(index: 3, count: 3, title: TKLocales.LiveActivity.Stage.arrivingOn("TRON")),
                Stage(index: 3, count: 3, title: TKLocales.LiveActivity.Stage.arrivingOn("TRON")),
            ]),
        ]
        let start = Date()
        for (scenario, expected) in expectations {
            let stages = expected.stages
            let entry = Mock.Entry(
                id: UUID().uuidString,
                scenario: scenario,
                startedAt: start,
                resolvesAt: start.addingTimeInterval(Mock.resolveDelay)
            )
            let snapshots = try stages.indices.map { part in
                let at = Mock.resolveDelay * Double(part) / Double(stages.count) + 1
                return try XCTUnwrap(Mock.snapshot(for: entry, now: start.addingTimeInterval(at)), "\(scenario)")
            }
            let final = try XCTUnwrap(Mock.snapshot(for: entry, now: start.addingTimeInterval(Mock.resolveDelay)))

            XCTAssertEqual(snapshots.map(\.stage), stages, "\(scenario)")
            XCTAssertEqual(Set(snapshots.map(\.title)), [expected.title], "\(scenario)")
            XCTAssertEqual(Set(snapshots.map(\.id)), [final.id], "\(scenario)")
            XCTAssertNil(final.stage, "\(scenario)")
            XCTAssertEqual(final.steps, 3, "\(scenario)")
        }
    }

    func test_aDepositThroughTheBridgeIsCreditedRatherThanConverted() {
        func arriving(executionId: String) -> String? {
            var deposit = PerpsPendingDeposit(
                stage: .registeredPending,
                route: .crosschainSwap,
                beneficiary: "0xabc",
                sourceAsset: PerpsFundingAsset(assetId: "arb/mainnet/erc20/0xaf88", symbol: "USDC", decimals: 6),
                sourceAmountUnits: "5000000",
                targetAsset: PerpsFundingAsset(assetId: "eth/mainnet/erc20/0xa0b8", symbol: "USDC", decimals: 6)
            )
            deposit.executionId = executionId
            return TransactionLiveActivitySnapshot(funding: PerpsPendingFundingOperation(
                operationId: "op",
                walletId: "wallet",
                walletIdentity: "identity",
                environment: "test",
                details: .deposit(deposit)
            )).stage?.title
        }

        XCTAssertEqual(arriving(executionId: "funxyz_1"), TKLocales.LiveActivity.Stage.creditingToPerps)
        XCTAssertEqual(arriving(executionId: "exec-1"), TKLocales.LiveActivity.Stage.movingTo(MultichainChain.eth.shortDisplayTitle))
    }

    func test_crossChainSwapIsUnderwayUntilItsDestinationTransactionAppears() {
        func swap(to assetId: String) -> TransactionLiveActivitySnapshot {
            TransactionLiveActivitySnapshot(broadcast: MultichainPendingTransaction(
                walletId: "wallet",
                chain: .ton,
                network: .mainnet,
                txHash: "hash",
                activityType: .swap(.init(fromAssetId: "ton/mainnet/ton", toAssetId: assetId))
            ))
        }

        let crossChain = swap(to: "trx/mainnet/trx")
        let sameChain = swap(to: "ton/mainnet/jetton/EQCxE6mUtQJKFnGfaROTKOt1lZbDiiX1kCixRv7Nw2Id_sDs")

        XCTAssertEqual(crossChain.stage, .init(index: 1, count: 3, title: TKLocales.LiveActivity.Stage.sending))
        XCTAssertEqual(crossChain.steps, 3)
        XCTAssertEqual(crossChain.title, TKLocales.LiveActivity.Stage.movingTo("TRON"))
        XCTAssertNil(sameChain.steps)
        XCTAssertNil(sameChain.stage)
        XCTAssertEqual(sameChain.title, TKLocales.ActionTypes.swapping)
    }

    func test_fundingBarFitsEveryJournalStageIntoThreeSegments() {
        func deposit(_ stage: PerpsDepositStage, route: PerpsDepositRoute) -> TransactionLiveActivitySnapshot {
            TransactionLiveActivitySnapshot(funding: operation(.deposit(PerpsPendingDeposit(
                stage: stage,
                route: route,
                beneficiary: "0x1234567890123456789012345678901234567890",
                sourceAsset: PerpsFundingAsset(assetId: "ton/mainnet/coin", symbol: "TON", decimals: 9),
                sourceAmountUnits: "1250000000",
                targetAsset: PerpsFundingAsset(
                    assetId: "eth/mainnet/erc20/0xa0b86991c6218b36c1d19d4a2e9eb0ce3606eb48",
                    symbol: "USDC",
                    decimals: 6
                )
            ))))
        }
        func withdraw(_ stage: PerpsWithdrawStage) -> TransactionLiveActivitySnapshot {
            TransactionLiveActivitySnapshot(funding: operation(.withdraw(PerpsPendingWithdraw(
                stage: stage,
                accountIndex: 1,
                apiKeyIndex: 1,
                chainId: 1,
                assetIndex: 1,
                routeType: 1,
                amountUnits: "10"
            ))))
        }
        let depositStages: [PerpsDepositStage] = [.sourcePending, .registrationPending, .registeredPending]
        let flows: [(String, [TransactionLiveActivitySnapshot])] = [
            ("converted deposit", depositStages.map { deposit($0, route: .crosschainSwap) }),
            ("direct deposit", depositStages.map { deposit($0, route: .directGateway) }),
            ("withdrawal", [.signed, .sending, .accepted, .awaitingL1].map(withdraw)),
        ]

        let indexes = ["converted deposit": [1, 2, 3], "direct deposit": [1, 2, 3], "withdrawal": [1, 1, 2, 3]]
        for (flow, snapshots) in flows {
            let stages = snapshots.compactMap(\.stage)
            XCTAssertEqual(stages.map(\.index), indexes[flow], flow)
            XCTAssertEqual(Set(stages.map(\.count)), [3], flow)
            XCTAssertEqual(Set(snapshots.map(\.title)).count, 1, flow)
            XCTAssertEqual(Set(snapshots.map(\.steps)), [3], flow)
        }
        XCTAssertEqual(
            depositStages.map { deposit($0, route: .directGateway).stage?.title },
            [
                TKLocales.LiveActivity.Stage.sendingFromWallet,
                TKLocales.LiveActivity.Stage.creditingToPerps,
                TKLocales.LiveActivity.Stage.creditingToPerps,
            ]
        )
        XCTAssertEqual(
            deposit(.needsAuthorization, route: .crosschainSwap).stage,
            .init(index: 2, count: 3, title: TKLocales.LiveActivity.Stage.convertingTo("USDC"))
        )
        XCTAssertEqual(deposit(.sourcePending, route: .crosschainSwap).kind, .deposit)
        XCTAssertEqual(withdraw(.signed).kind, .withdrawal)
    }

    func test_pendingMockWaitsForManualResolution() throws {
        let entry = Mock.Entry(id: "manual", scenario: .sendPending, startedAt: Date(), resolvesAt: nil)

        let snapshot = try XCTUnwrap(Mock.snapshot(for: entry, now: Date().addingTimeInterval(60 * 60)))

        XCTAssertEqual(snapshot.status, .pending)
    }

    func test_perpsTradeTitlesFollowPayloadSideAndOutcome() {
        let close = trading(side: .long, payload: .close)
        let margin = trading(side: .short, payload: .marginChange(.init(direction: .add, allocatedMarginBefore: 10, amountUsd: 1)))

        XCTAssertEqual(TransactionLiveActivitySnapshot(trading: close).title, TKLocales.LiveActivity.closingLong)
        XCTAssertEqual(
            TransactionLiveActivitySnapshot(trading: close, status: .confirmed).title,
            TKLocales.MultichainHistory.Perps.closedLong
        )
        XCTAssertEqual(TransactionLiveActivitySnapshot(trading: close, status: .failed).title, TKLocales.State.failed)
        XCTAssertEqual(TransactionLiveActivitySnapshot(trading: close).kind, .close)
        XCTAssertEqual(TransactionLiveActivitySnapshot(trading: margin).kind, .other)
        XCTAssertEqual(TransactionLiveActivitySnapshot(trading: margin).title, TKLocales.ActionTypes.pending)
        XCTAssertEqual(
            TransactionLiveActivitySnapshot(trading: margin, status: .confirmed).title,
            TKLocales.Result.success
        )
    }

    func test_settledTradeOverridesItsPendingEntry() {
        let action = trading(side: .short, payload: .open(limitPrice: nil))
        let pending = TransactionLiveActivitySnapshot(trading: action)
        let settled = TransactionLiveActivitySnapshot(trading: action, status: .confirmed)

        XCTAssertEqual(TransactionLiveActivitySelection.matching(pending.id, in: [pending, settled])?.status, .confirmed)
        XCTAssertNil(TransactionLiveActivitySelection.nextPending(in: [pending, settled]))
    }

    func test_perpsTradeLinksToItsMarketWithAmountsHiddenToo() throws {
        let snapshot = TransactionLiveActivitySnapshot(trading: trading(side: .long, payload: .close))
        let metaData = WalletMetaData(label: "Wallet", tintColor: .SteelGray, icon: .icon(.wallet))

        for hidesAmounts in [false, true] {
            let state = TransactionLiveActivityMonitor.contentState(
                for: snapshot,
                walletMetaData: metaData,
                hidesAmounts: hidesAmounts
            )
            let url = try XCTUnwrap(TransactionLiveActivityLink(
                walletId: "wallet",
                transactionId: state.transactionId,
                perpsMarketId: state.perpsMarketId
            ).url(on: .lockScreen))

            XCTAssertEqual(TransactionLiveActivityLink(url: url)?.perpsMarketId, 1, "hidesAmounts: \(hidesAmounts)")
        }
    }

    func test_tradeShowsItsSizeAndIsPricedAtTheMarkPrice() throws {
        let icon = try XCTUnwrap(URL(string: "https://example.com/eth.png"))
        let close = TransactionLiveActivitySnapshot(
            trading: PerpsPendingTradingAction(
                operationId: "operation",
                walletId: "wallet",
                marketId: 2,
                side: .short,
                payload: .close,
                expectedBaseSize: 0.5
            ),
            marketSymbol: "ETH",
            marketIcon: icon,
            markPrice: 3400
        )

        XCTAssertEqual(close.destination?.amount, "0.5")
        XCTAssertEqual(close.value, .usd(1700))
        XCTAssertEqual(close.icon, .url(icon))
    }

    func test_mockTransfersCarryTheirLogoAndDollarValue() throws {
        let start = Date()
        func snapshot(_ scenario: Mock.Scenario) throws -> TransactionLiveActivitySnapshot {
            let entry = Mock.Entry(id: "\(scenario)", scenario: scenario, startedAt: start, resolvesAt: nil)
            return try XCTUnwrap(Mock.snapshot(for: entry, now: start))
        }

        XCTAssertEqual(try snapshot(.sendPending).icon, .ton)
        XCTAssertEqual(try snapshot(.sendPending).value, .usd(3.4))
        XCTAssertEqual(try snapshot(.receiveConfirmed).icon, .usdt)
        XCTAssertEqual(try snapshot(.swapConfirmed).icon, .ton)
        XCTAssertNil(try snapshot(.swapConfirmed).value)
    }

    private func trading(side: PerpsTradeSide, payload: PerpsPendingPayload) -> PerpsPendingTradingAction {
        PerpsPendingTradingAction(
            operationId: "operation",
            walletId: "wallet",
            marketId: 1,
            side: side,
            payload: payload
        )
    }

    private func operation(_ details: PerpsPendingFundingDetails) -> PerpsPendingFundingOperation {
        PerpsPendingFundingOperation(
            operationId: "operation",
            walletId: "backend-wallet",
            walletIdentity: "local-wallet",
            environment: "test",
            details: details
        )
    }
}
