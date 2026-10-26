@testable import App
import Foundation
@testable import KeeperCore
import PerpsModels
import TKLocalize
import TonSwift
import XCTest

@available(iOS 16.2, *)
final class TransactionLiveActivitySelectionTests: XCTestCase {
    func test_matchingPrefersTerminalStatusAndComparesHashCaseInsensitively() {
        let pending = activity(id: "0xAbC", status: .pending)
        let confirmed = activity(id: "0xabc", status: .confirmed)

        XCTAssertEqual(
            TransactionLiveActivitySelection.matching(
                "ton:0xABC",
                in: [snapshot(pending), snapshot(confirmed)]
            )?.status,
            .confirmed
        )
    }

    func test_broadcastStartsImmediatelyAndFollowsIndexedTransaction() {
        let broadcast = TransactionLiveActivitySnapshot(broadcast: MultichainPendingTransaction(
            walletId: "backend-wallet",
            chain: .eth,
            network: .mainnet,
            txHash: "0xAbC",
            activityType: .send
        ))
        let indexed = snapshot(activity(id: "0xabc", status: .confirmed, chain: .eth))

        XCTAssertEqual(broadcast.id, "eth:0xabc")
        XCTAssertEqual(broadcast.status, .pending)
        XCTAssertEqual(broadcast.kind, .send)
        XCTAssertEqual(TransactionLiveActivitySelection.nextPending(in: [broadcast])?.id, broadcast.id)
        XCTAssertEqual(TransactionLiveActivitySelection.matching(broadcast.id, in: [broadcast, indexed])?.status, .confirmed)
        XCTAssertNil(TransactionLiveActivitySelection.nextPending(in: [broadcast, indexed]))
    }

    func test_broadcastSwapMatchesIndexedSwap() {
        let broadcast = TransactionLiveActivitySnapshot(broadcast: MultichainPendingTransaction(
            walletId: "backend-wallet",
            chain: .ton,
            network: .mainnet,
            txHash: "source",
            activityType: .swap(.init(fromAssetId: "ton/mainnet/coin", toAssetId: "ton/mainnet/jetton"))
        ))
        let indexed = snapshot(activity(id: "source", status: .pending, type: .swap))

        XCTAssertEqual(broadcast.id, "swap:ton:source")
        XCTAssertEqual(broadcast.kind, .swap)
        XCTAssertEqual(TransactionLiveActivitySelection.matching(broadcast.id, in: [indexed])?.id, indexed.id)
    }

    func test_nextPendingSkipsSpamAndItemsWithoutTransactionId() {
        let spam = activity(id: "spam", status: .pending, isSpam: true)
        let noId = activity(id: "", status: .pending)
        let valid = activity(id: "valid", status: .pending)

        XCTAssertEqual(
            TransactionLiveActivitySelection.nextPending(
                in: [spam, noId, valid].compactMap(TransactionLiveActivitySnapshot.init)
            )?.id,
            "ton:valid"
        )
    }

    func test_nextPendingSkipsDismissedAndAlreadyConfirmedTransactions() {
        let dismissed = activity(id: "dismissed", status: .pending)
        let oldPending = activity(id: "settled", status: .pending)
        let settled = activity(id: "settled", status: .confirmed)
        let next = activity(id: "next", status: .pending)

        XCTAssertEqual(
            TransactionLiveActivitySelection.nextPending(
                in: [dismissed, oldPending, settled, next].compactMap(TransactionLiveActivitySnapshot.init),
                excluding: ["wallet:ton:dismissed"],
                walletId: "wallet"
            )?.id,
            "ton:next"
        )
    }

    func test_newerTransactionTakesOverTheActivityWhileAnOlderOneWaits() {
        let now = Date()
        let current = activity(id: "current", status: .pending, date: now)
        let newer = activity(id: "newer", status: .pending, date: now.addingTimeInterval(60))
        let older = activity(id: "older", status: .pending, date: now.addingTimeInterval(-60))

        XCTAssertEqual(step(in: [current, newer], next: newer), "replace ton:newer")
        XCTAssertEqual(step(in: [current, older], next: older), "follow ton:current")
    }

    func test_settledTransactionHandsTheActivityOverOrEndsIt() {
        let settled = activity(id: "current", status: .confirmed)
        let next = activity(id: "next", status: .pending)

        XCTAssertEqual(step(in: [settled, next], next: next), "settle ton:current confirmed → ton:next")
        XCTAssertEqual(step(in: [settled]), "settle ton:current confirmed → end")
        XCTAssertEqual(step(status: .confirmed, in: [], next: next), "settle shown → ton:next")
    }

    func test_missingTransactionGivesWayOnlyToACompleteRefresh() {
        let next = activity(id: "next", status: .pending)
        let longAgo = Date().addingTimeInterval(-TransactionLiveActivitySelection.unseenLimit - 1)

        XCTAssertEqual(step(in: [next], next: next), "stay")
        XCTAssertEqual(step(in: [next], next: next, judgesAbsence: true), "replace ton:next")
        XCTAssertEqual(step(in: [], judgesAbsence: true), "stay")
        XCTAssertEqual(step(updatedAt: longAgo, in: [], judgesAbsence: true), "settle unknown → end")
        XCTAssertEqual(step(tracking: "perps-operation", in: [], perpsLoaded: true), "settle unknown → end")
    }

    func test_tronHistoryTerminalStatusOverridesMultichainPending() throws {
        let pending = snapshot(activity(id: "ABC", status: .pending, chain: .tron))
        let transaction = try JSONDecoder().decode(TronTransaction.self, from: Data(
            """
            {
              "txid": "abc",
              "timestamp": 1,
              "from_account": "TR7NHqjeKQxGTCi8q8ZY4pL8otSzgjLj6t",
              "to_account": "T9yD14Nj9j7xAB4dbGeiX9h8unkKHxuWwb",
              "amount": "10",
              "is_pending": false,
              "is_failed": true,
              "token": "trx"
            }
            """.utf8
        ))
        let failed = TransactionLiveActivitySnapshot(transaction: transaction)

        XCTAssertEqual(pending.id, failed.id)
        XCTAssertEqual(failed.status, .failed)
        XCTAssertEqual(failed.detail, "TRX")
        let received = TransactionLiveActivitySnapshot(transaction: transaction, walletAddress: transaction.toAccount)
        XCTAssertEqual(received.source?.network, "TRON")
        XCTAssertEqual(received.destination?.currency, "TRX")
        XCTAssertNil(received.source?.amount)
        XCTAssertNotNil(received.destination?.amount)
        XCTAssertEqual(received.kind, .receive)
        XCTAssertEqual(received.counterpartyAddress, transaction.fromAccount.base58)
        XCTAssertEqual(
            TransactionLiveActivitySelection.matching(pending.id, in: [pending, failed])?.status,
            .failed
        )
        XCTAssertNil(TransactionLiveActivitySelection.nextPending(in: [pending, failed]))
    }

    func test_perpsWithdrawalMapsPendingAndTerminalStages() {
        var withdrawal = PerpsPendingWithdraw(
            stage: .signed,
            accountIndex: 1,
            apiKeyIndex: 1,
            chainId: 1,
            assetIndex: 1,
            routeType: 1,
            amountUnits: "10"
        )
        var operation = PerpsPendingFundingOperation(
            operationId: "operation",
            walletId: "backend-wallet",
            walletIdentity: "local-wallet",
            environment: "test",
            details: .withdraw(withdrawal)
        )

        XCTAssertEqual(TransactionLiveActivitySnapshot(funding: operation).status, .pending)
        XCTAssertEqual(TransactionLiveActivitySnapshot(funding: operation).source?.currency, "USDC")
        XCTAssertEqual(TransactionLiveActivitySnapshot(funding: operation).destination?.network, "ETH")
        XCTAssertNotNil(TransactionLiveActivitySnapshot(funding: operation).source?.amount)
        withdrawal.stage = .settled
        operation.details = .withdraw(withdrawal)
        XCTAssertEqual(TransactionLiveActivitySnapshot(funding: operation).status, .confirmed)
        withdrawal.stage = .rejected
        operation.details = .withdraw(withdrawal)
        XCTAssertEqual(TransactionLiveActivitySnapshot(funding: operation).status, .failed)
    }

    func test_perpsDepositShowsBothNetworksCurrenciesAndDeclaredCredit() {
        let deposit = PerpsPendingDeposit(
            stage: .registeredPending,
            route: .crosschainSwap,
            beneficiary: "0x1234567890123456789012345678901234567890",
            sourceAsset: PerpsFundingAsset(assetId: "ton/mainnet/coin", symbol: "TON", decimals: 9),
            sourceAmountUnits: "1250000000",
            targetAsset: PerpsFundingAsset(
                assetId: "eth/mainnet/erc20/0xa0b86991c6218b36c1d19d4a2e9eb0ce3606eb48",
                symbol: "USDC",
                decimals: 6
            ),
            creditedAmount: "2.75"
        )
        let operation = PerpsPendingFundingOperation(
            operationId: "deposit",
            walletId: "backend-wallet",
            walletIdentity: "local-wallet",
            environment: "test",
            details: .deposit(deposit)
        )
        let snapshot = TransactionLiveActivitySnapshot(funding: operation)

        XCTAssertEqual(snapshot.source?.network, "TON")
        XCTAssertEqual(snapshot.source?.currency, "TON")
        XCTAssertEqual(snapshot.destination?.network, "ETH")
        XCTAssertEqual(snapshot.destination?.currency, "USDC")
        XCTAssertNotNil(snapshot.source?.amount)
        XCTAssertNotNil(snapshot.destination?.amount)
    }

    func test_perpsOpenShowsMarketSizeWhenKnown() {
        let operation = PerpsPendingTradingAction(
            operationId: "open",
            walletId: "wallet",
            marketId: 1,
            side: .long,
            payload: .open(limitPrice: nil),
            expectedBaseSize: 0.01234
        )
        let snapshot = TransactionLiveActivitySnapshot(trading: operation, marketSymbol: "BTC")

        XCTAssertEqual(snapshot.destination?.network, "PERPS")
        XCTAssertEqual(snapshot.destination?.currency, "BTC")
        XCTAssertNotNil(snapshot.destination?.amount)
    }

    func test_doesNotStartActivityForOldPendingTransaction() {
        let old = activity(id: "old", status: .pending, date: Date().addingTimeInterval(-9 * 60 * 60))
        XCTAssertNil(TransactionLiveActivitySelection.nextPending(in: [snapshot(old)]))
    }

    func test_incomingBTCTransferUsesReceivingTitle() {
        let incoming = snapshot(activity(
            id: "btc:incoming",
            status: .pending,
            type: .receive,
            chain: .btc,
            direction: .incoming,
            inToken: asset("BTC", chain: .btc)
        ))

        XCTAssertEqual(incoming.id, "btc:incoming")
        XCTAssertEqual(incoming.title, TKLocales.ActionTypes.receiving)
        XCTAssertEqual(incoming.chain, "BTC")
        XCTAssertEqual(incoming.detail, "BTC")
        XCTAssertEqual(TransactionLiveActivitySelection.nextPending(in: [incoming])?.id, incoming.id)
    }

    func test_crossChainReceiveDoesNotClaimDestinationTokenAsSourceCurrency() {
        let incoming = snapshot(activity(
            id: "btc:incoming",
            status: .pending,
            type: .receive,
            chain: .ton,
            toChain: .btc,
            direction: .incoming,
            inToken: asset("BTC", chain: .btc)
        ))

        XCTAssertEqual(incoming.source?.network, "TON")
        XCTAssertNil(incoming.source?.currency)
        XCTAssertEqual(incoming.destination?.network, "BTC")
        XCTAssertEqual(incoming.destination?.currency, "BTC")
    }

    func test_BTCBridgeTracksEitherLegWithoutConfusingDestinationReceive() {
        let pending = snapshot(activity(
            id: "ton:source",
            status: .pending,
            type: .bridge,
            toChain: .btc,
            outToken: asset("TON", chain: .ton),
            inToken: asset("BTC", chain: .btc),
            transactionIds: ["ton:source", "btc:destination"]
        ))
        let destinationReceive = snapshot(activity(
            id: "btc:destination",
            status: .confirmed,
            type: .receive,
            chain: .btc,
            direction: .incoming
        ))
        let completedSwap = snapshot(activity(
            id: "btc:destination",
            status: .confirmed,
            type: .bridge,
            chain: .ton,
            toChain: .btc,
            outToken: asset("TON", chain: .ton),
            inToken: asset("BTC", chain: .btc),
            transactionIds: ["btc:destination", "ton:source"]
        ))

        XCTAssertEqual(pending.id, "swap:ton:source")
        XCTAssertEqual(pending.title, TKLocales.LiveActivity.Stage.receiving("BTC"))
        XCTAssertEqual(pending.stage, .init(index: 3, count: 4))
        XCTAssertNil(completedSwap.stage)
        XCTAssertEqual(pending.chain, "BTC")
        XCTAssertEqual(pending.detail, "TON → BTC")
        XCTAssertEqual(
            TransactionLiveActivitySelection.matching(pending.id, in: [pending, destinationReceive])?.status,
            .pending
        )
        XCTAssertEqual(
            TransactionLiveActivitySelection.matching(pending.id, in: [pending, completedSwap])?.status,
            .confirmed
        )
        XCTAssertNil(TransactionLiveActivitySelection.nextPending(in: [pending, completedSwap]))
    }

    func test_crossChainSwapArrivesUnderAnAssetIdStyleChainPrefix() {
        let swap = snapshot(activity(
            id: "ton:source",
            status: .pending,
            type: .bridge,
            toChain: .tron,
            outToken: asset("USDT", chain: .ton),
            inToken: asset("USDT", chain: .tron),
            transactionIds: ["ton:source", "TRX:destination"]
        ))

        XCTAssertEqual(swap.stage, .init(index: 3, count: 4))
        XCTAssertEqual(swap.title, TKLocales.LiveActivity.Stage.receiving("USDT"))
        XCTAssertNotNil(TransactionLiveActivitySelection.matching("swap:tron:destination", in: [swap]))
    }

    func test_pendingBTCSwapShowsRouteBeforeTokenDetailsArrive() {
        let swap = snapshot(activity(id: "ton:source", status: .pending, type: .swap, toChain: .btc))

        XCTAssertEqual(swap.id, "swap:ton:source")
        XCTAssertEqual(swap.title, TKLocales.LiveActivity.Stage.movingTo("BTC"))
        XCTAssertEqual(swap.stage, .init(index: 2, count: 4))
        XCTAssertEqual(swap.chain, "BTC")
        XCTAssertEqual(swap.detail, "TON → BTC")
        XCTAssertEqual(swap.source?.network, "TON")
        XCTAssertEqual(swap.destination?.network, "BTC")
        XCTAssertNil(swap.source?.currency)
    }

    func test_swapShowsBothCurrenciesAndCompactAmounts() {
        let swap = snapshot(activity(
            id: "swap",
            status: .pending,
            type: .swap,
            chain: .ton,
            toChain: .btc,
            outToken: asset("USDT", chain: .ton),
            inToken: asset("BTC", chain: .btc),
            outAmount: "12345678900",
            inAmount: "1234567"
        ))

        XCTAssertEqual(swap.source?.network, "TON")
        XCTAssertEqual(swap.source?.currency, "USDT")
        XCTAssertEqual(swap.destination?.network, "BTC")
        XCTAssertEqual(swap.destination?.currency, "BTC")
        XCTAssertNotNil(swap.source?.amount)
        XCTAssertNotNil(swap.destination?.amount)
        XCTAssertFalse(swap.source?.amount?.contains("12345678900") ?? true)
        XCTAssertEqual(swap.kind, .swap)
        XCTAssertNil(swap.counterpartyAddress)
    }

    func test_sendAndReceiveUseWalletIdentityAndCounterpartyAddress() {
        let metaData = WalletMetaData(label: "Savings", tintColor: .SteelGray, icon: .emoji("⭐️"))
        let send = snapshot(activity(
            id: "send",
            status: .pending,
            toAddress: "UQabcdefghijklmnopqrstuvwxyz0123456789"
        ))
        let sendState = TransactionLiveActivityMonitor.contentState(for: send, walletMetaData: metaData)
        XCTAssertEqual(sendState.kind, .send)
        XCTAssertEqual(sendState.wallet?.name, "Savings")
        XCTAssertEqual(sendState.wallet?.emoji, "⭐️")
        XCTAssertEqual(sendState.counterpartyAddress, "UQabcdefghijklmnopqrstuvwxyz0123456789")

        let receive = snapshot(activity(
            id: "receive",
            status: .pending,
            type: .receive,
            direction: .incoming,
            fromAddress: "0x1234567890123456789012345678901234567890"
        ))
        let receiveState = TransactionLiveActivityMonitor.contentState(for: receive, walletMetaData: metaData)
        XCTAssertEqual(receiveState.kind, .receive)
        XCTAssertEqual(receiveState.counterpartyAddress, "0x1234567890123456789012345678901234567890")
        XCTAssertEqual(receiveState.wallet?.name, "Savings")

        let iconState = TransactionLiveActivityMonitor.contentState(
            for: send,
            walletMetaData: WalletMetaData(label: "Wallet", tintColor: .SteelGray, icon: .icon(.wallet))
        )
        XCTAssertEqual(iconState.wallet?.icon, "wallet")
    }

    func test_ownWalletCounterpartyIsNamedAndAnExternalOneIsAnAddress() throws {
        let shown = wallet(id: "shown", label: "Main", key: 1)
        let savings = wallet(id: "savings", label: "Savings", key: 2, addresses: [
            MultichainWalletAddress(chain: .eth, address: "0xAbCdEf0123456789aBcDeF0123456789AbCdEf01"),
        ])
        let testnet = wallet(id: "testnet", label: "Testnet", key: 3, network: .testnet)
        let stored = TransactionLiveActivityCounterparties([shown, savings, testnet])
        let counterparties = try JSONDecoder().decode(
            TransactionLiveActivityCounterparties.self,
            from: JSONEncoder().encode(stored)
        )
        func label(_ address: String) -> String? {
            counterparties.label(for: address, shownWalletId: shown.id)
        }
        let savingsAddress = try savings.address
        let testnetAddress = try testnet.address.toRaw()
        let external = "UQabcdefghijklmnopqrstuvwxyz0123456789"

        XCTAssertEqual(counterparties, stored)
        XCTAssertEqual(label(savingsAddress.toString(bounceable: false)), "Savings")
        XCTAssertEqual(label(savingsAddress.toString(urlSafe: false, bounceable: true)), "Savings")
        XCTAssertEqual(label(savingsAddress.toRaw().uppercased()), "Savings")
        XCTAssertEqual(label("0xabcdef0123456789abcdef0123456789abcdef01"), "Savings")
        XCTAssertNil(try label(shown.address.toString()))
        XCTAssertEqual(label(testnetAddress), TransactionLiveActivityCounterparties.shortened(testnetAddress))
        XCTAssertEqual(label(external), "UQab...6789")
        XCTAssertEqual(counterparties.label(for: external, shownWalletId: "unknown"), "UQab...6789")

        let send = snapshot(activity(id: "send", status: .pending, toAddress: savingsAddress.toString()))
        let state = TransactionLiveActivityMonitor.contentState(for: send, walletMetaData: shown.metaData)
        XCTAssertEqual(TransactionLiveActivityPresentation(state: state, isStale: false, counterparty: label).subtitle, "TON · Savings")
        XCTAssertEqual(TransactionLiveActivityPresentation(state: state, isStale: false).subtitle, "TON · " + TransactionLiveActivityCounterparties.shortened(savingsAddress.toString()))
        XCTAssertNil(
            TransactionLiveActivityMonitor.contentState(for: send, walletMetaData: shown.metaData, hidesAmounts: true)
                .counterpartyAddress
        )
    }

    func test_plainLegOfKnownExchangeStartsNoActivityOfItsOwn() {
        let leg = snapshot(activity(id: "ton:source", status: .pending))
        let bridge = snapshot(activity(
            id: "ton:source",
            status: .pending,
            type: .bridge,
            date: Date().addingTimeInterval(-60),
            toChain: .btc,
            outToken: asset("TON", chain: .ton),
            inToken: asset("BTC", chain: .btc)
        ))

        XCTAssertEqual(TransactionLiveActivitySelection.nextPending(in: [leg, bridge])?.id, "swap:ton:source")
    }

    func test_activityStartedForPlainTransferFollowsTheExchangeItTurnsOutToBe() {
        let confirmedLeg = snapshot(activity(id: "ton:source", status: .confirmed))
        let pendingBridge = snapshot(activity(
            id: "ton:source",
            status: .pending,
            type: .bridge,
            toChain: .btc,
            outToken: asset("TON", chain: .ton),
            inToken: asset("BTC", chain: .btc)
        ))

        let followed = TransactionLiveActivitySelection.matching("ton:source", in: [confirmedLeg, pendingBridge])
        XCTAssertEqual(followed?.status, .pending)
        XCTAssertEqual(followed?.kind, .swap)
        XCTAssertEqual(TransactionLiveActivitySelection.matching("ton:source", in: [confirmedLeg])?.status, .confirmed)
        XCTAssertNil(TransactionLiveActivitySelection.matching("swap:ton:source", in: [confirmedLeg]))
    }

    func test_chainOfIdIgnoresExchangePrefix() {
        XCTAssertEqual(TransactionLiveActivitySelection.chain(of: "swap:TON:abc"), "ton")
        XCTAssertEqual(TransactionLiveActivitySelection.chain(of: "tron:abc"), "tron")
    }

    func test_hiddenBalancesKeepAmountsAndCounterpartyOffTheLockScreen() {
        let send = snapshot(activity(
            id: "send",
            status: .pending,
            outToken: asset("TON", chain: .ton),
            outAmount: "1000000000",
            toAddress: "UQabcdefghijklmnopqrstuvwxyz0123456789"
        ))
        let metaData = WalletMetaData(label: "Savings", tintColor: .SteelGray, icon: .emoji("⭐️"))

        let shown = TransactionLiveActivityMonitor.contentState(for: send, walletMetaData: metaData)
        let hidden = TransactionLiveActivityMonitor.contentState(for: send, walletMetaData: metaData, hidesAmounts: true)

        XCTAssertNotNil(shown.source?.amount)
        XCTAssertNotNil(shown.counterpartyAddress)
        XCTAssertNil(hidden.source?.amount)
        XCTAssertNil(hidden.destination?.amount)
        XCTAssertNil(hidden.counterpartyAddress)
        XCTAssertEqual(hidden.source?.currency, "TON")
        XCTAssertEqual(hidden.title, shown.title)

        let redacted = TransactionLiveActivityMonitor.redactedState(from: shown)
        XCTAssertNil(redacted.source?.amount)
        XCTAssertNil(redacted.destination?.amount)
        XCTAssertNil(redacted.counterpartyAddress)
        XCTAssertEqual(redacted.status, shown.status)
        XCTAssertEqual(redacted.updatedAt, shown.updatedAt)
        XCTAssertEqual(redacted, TransactionLiveActivityMonitor.redactedState(from: redacted))
    }

    func test_startedIdsForgetEntriesPastTheStartWindow() throws {
        let suite = "TransactionLiveActivitySelectionTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let now = Date()
        let key = TransactionLiveActivityMonitor.startedIdsKey

        let window = TransactionLiveActivitySelection.startWindow
        defaults.set([
            "wallet:ton:recent": now.addingTimeInterval(-window + 60),
            "wallet:ton:old": now.addingTimeInterval(-window - 60),
        ], forKey: key)
        XCTAssertEqual(
            Set(TransactionLiveActivityMonitor.loadStartedIds(from: defaults, now: now).keys),
            ["wallet:ton:recent"]
        )
    }

    private func wallet(
        id: String,
        label: String,
        key: UInt8,
        network: Network = .mainnet,
        addresses: [MultichainWalletAddress] = []
    ) -> Wallet {
        Wallet(
            id: id,
            identity: WalletIdentity(
                network: network,
                kind: .Regular(TonSwift.PublicKey(data: Data(repeating: key, count: 32)), .v4R2)
            ),
            metaData: WalletMetaData(label: label, tintColor: .SteelGray, icon: .emoji("⭐️")),
            setupSettings: WalletSetupSettings(isSetupFinished: true),
            batterySettings: BatterySettings(),
            multichain: .multichain(MultichainWalletState(walletId: id, addresses: addresses))
        )
    }

    private func snapshot(_ activity: MultichainActivity) -> TransactionLiveActivitySnapshot {
        TransactionLiveActivitySnapshot(activity: activity)!
    }

    private func step(
        tracking id: String = "ton:current",
        status: TransactionLiveActivitySnapshot.Status = .pending,
        updatedAt: Date = Date(),
        in snapshots: [MultichainActivity],
        next: MultichainActivity? = nil,
        perpsLoaded: Bool = false,
        judgesAbsence: Bool = false
    ) -> String {
        let step = TransactionLiveActivitySelection.step(
            tracking: id,
            status: status,
            updatedAt: updatedAt,
            in: snapshots.map(snapshot),
            next: next.map(snapshot),
            perpsLoaded: perpsLoaded,
            judgesAbsence: judgesAbsence
        )
        switch step {
        case .stay:
            return "stay"
        case let .follow(snapshot):
            return "follow \(snapshot.id)"
        case let .replace(snapshot):
            return "replace \(snapshot.id)"
        case let .settle(outcome, next):
            let settled = switch outcome {
            case .shown: "shown"
            case let .reached(snapshot): "\(snapshot.id) \(snapshot.status)"
            case .unknown: "unknown"
            }
            return "settle \(settled) → \(next?.id ?? "end")"
        }
    }

    private func activity(
        id: String,
        status: MultichainActivityStatus,
        type: MultichainActivityType = .send,
        isSpam: Bool = false,
        chain: MultichainChain = .ton,
        date: Date = Date(),
        toChain: MultichainChain? = nil,
        direction: MultichainActivityDirection = .outgoing,
        outToken: MultichainAssetDetails? = nil,
        inToken: MultichainAssetDetails? = nil,
        transactionIds: [String]? = nil,
        outAmount: String? = nil,
        inAmount: String? = nil,
        walletAddress: String? = nil,
        fromAddress: String? = nil,
        toAddress: String? = nil
    ) -> MultichainActivity {
        MultichainActivity(
            activityType: type,
            status: status,
            blockTime: date,
            blockNumber: nil,
            fromChain: chain,
            toChain: toChain ?? chain,
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
            protocolName: nil,
            txIds: transactionIds ?? (id.isEmpty ? [] : [id]),
            isRead: nil,
            isSpam: isSpam
        )
    }

    private func asset(_ symbol: String, chain: MultichainChain) -> MultichainAssetDetails {
        MultichainAssetDetails(
            assetId: "\(chain.rawValue):coin",
            chain: chain,
            name: symbol,
            symbol: symbol,
            decimals: 9,
            image: ""
        )
    }
}
