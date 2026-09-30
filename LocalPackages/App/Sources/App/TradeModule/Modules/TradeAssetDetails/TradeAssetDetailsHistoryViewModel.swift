import Combine
import Foundation
import KeeperCore
import SwiftUI
import TKLocalize
import TKLogging
import TKUIKit
import TonSwift
import TronSwift
import UIKit

enum TradeAssetHistoryContext {
    case ton(wallet: Wallet)
    case jetton(wallet: Wallet, jettonMasterAddress: TonSwift.Address)
    case tronUSDT(wallet: Wallet)
    case tronTRX(wallet: Wallet)
}

enum TradeAssetHistorySelection {
    case ton(wallet: Wallet, event: AccountEventDetailsEvent)
    case tron(wallet: Wallet, event: TronTransaction)
}

struct TradeAssetDetailsHistoryPreview {
    struct Item {
        let id: String
        let icon: TKUIKit.TransactionCellContent.Icon
        let title: String
        let subtitle: String
        let amountText: String
        let amountStyle: TKUIKit.TransactionCellContent.AmountStyle
        let dateText: String
        let selection: TradeAssetHistorySelection
    }

    let context: TradeAssetHistoryContext
    let items: [Item]
}

@MainActor
protocol TradeAssetDetailsHistoryViewModeling: AnyObject {
    var statePublisher: AnyPublisher<TradeAssetDetailsHistoryPreview?, Never> { get }
    func scheduleUpdate()
}

@MainActor
final class TradeAssetDetailsHistoryViewModel: ObservableObject, TradeAssetDetailsHistoryViewModeling {
    @Published private(set) var state: TradeAssetDetailsHistoryPreview?

    private let wallet: Wallet?
    private let typedAssetId: TradingAssetToken?
    private let historyService: HistoryService
    private let tronUSDTHistoryService: HistoryService
    private let tronTRXHistoryService: HistoryService
    private let tronUsdtApi: TronUSDTAPI
    private let accountEventMapper: AccountEventMapper
    private let dateFormatter: DateFormatter
    private let signedAmountFormatter: AmountFormatter
    private let walletNFTsManagementStoreProvider: (Wallet) -> WalletNFTsManagementStore
    private let backgroundUpdate: BackgroundUpdate

    private var task: Task<Void, Never>?

    var statePublisher: AnyPublisher<TradeAssetDetailsHistoryPreview?, Never> {
        $state.eraseToAnyPublisher()
    }

    init(
        wallet: Wallet?,
        typedAssetId: TradingAssetToken?,
        historyService: HistoryService,
        tronUSDTHistoryService: HistoryService,
        tronTRXHistoryService: HistoryService,
        tronUsdtApi: TronUSDTAPI,
        accountEventMapper: AccountEventMapper,
        dateFormatter: DateFormatter,
        signedAmountFormatter: AmountFormatter,
        walletNFTsManagementStoreProvider: @escaping (Wallet) -> WalletNFTsManagementStore,
        backgroundUpdate: BackgroundUpdate
    ) {
        self.wallet = wallet
        self.typedAssetId = typedAssetId
        self.historyService = historyService
        self.tronUSDTHistoryService = tronUSDTHistoryService
        self.tronTRXHistoryService = tronTRXHistoryService
        self.tronUsdtApi = tronUsdtApi
        self.accountEventMapper = accountEventMapper
        self.dateFormatter = dateFormatter
        self.signedAmountFormatter = signedAmountFormatter
        self.walletNFTsManagementStoreProvider = walletNFTsManagementStoreProvider
        self.backgroundUpdate = backgroundUpdate

        backgroundUpdate.addEventObserver(self) { observer, wallet, _ in
            Task { @MainActor in
                observer.handleHistoryUpdate(wallet: wallet)
            }
        }
    }

    deinit {
        task?.cancel()
    }

    func scheduleUpdate() {
        primeCache()
        reload()
    }
}

private extension TradeAssetDetailsHistoryViewModel {
    func handleHistoryUpdate(wallet: Wallet) {
        guard wallet == self.wallet else {
            return
        }
        reload()
    }

    func primeCache() {
        guard let cached = cachedPreview() else {
            return
        }
        state = cached
    }

    func reload() {
        task?.cancel()
        task = Task { [weak self] in
            await self?.refresh()
        }
    }

    func refresh() async {
        let preview = await loadPreview()
        guard !Task.isCancelled else {
            return
        }
        state = preview
    }
}

private extension TradeAssetDetailsHistoryViewModel {
    func cachedPreview() -> TradeAssetDetailsHistoryPreview? {
        guard let context = historyContext() else {
            return nil
        }

        let events: [HistoryEvent]
        switch context {
        case let .ton(wallet):
            let cachedEvents = (try? HistoryListTonEventsCacheProvider(
                historyService: historyService
            ).getCache(wallet: wallet)) ?? []
            events = filteredTonHistoryEvents(cachedEvents)
        case let .jetton(wallet, jettonMasterAddress):
            events = (try? HistoryListJettonEventsCacheProvider(
                jettonMasterAddress: jettonMasterAddress,
                historyService: historyService
            ).getCache(wallet: wallet)) ?? []
        case let .tronUSDT(wallet):
            events = (try? HistoryListTronEventsCacheProvider(
                historyService: tronUSDTHistoryService
            ).getCache(wallet: wallet)) ?? []
        case let .tronTRX(wallet):
            events = (try? HistoryListTronEventsCacheProvider(
                historyService: tronTRXHistoryService
            ).getCache(wallet: wallet)) ?? []
        }

        return makePreview(events: events, context: context)
    }

    func loadPreview() async -> TradeAssetDetailsHistoryPreview? {
        guard let context = historyContext() else {
            return nil
        }

        do {
            let events = try await loadLatestEvents(for: context)
            return makePreview(events: events, context: context)
        } catch {
            return cachedPreview()
        }
    }

    func historyContext() -> TradeAssetHistoryContext? {
        guard let wallet else {
            return nil
        }

        switch typedAssetId {
        case .ton:
            return .ton(wallet: wallet)
        case let .jetton(jettonMasterAddress):
            return .jetton(wallet: wallet, jettonMasterAddress: jettonMasterAddress)
        case .tronUsdt:
            return .tronUSDT(wallet: wallet)
        case .tronTrx:
            return .tronTRX(wallet: wallet)
        case nil:
            return nil
        }
    }

    func loadLatestEvents(for context: TradeAssetHistoryContext) async throws -> [HistoryEvent] {
        switch context {
        case let .ton(wallet):
            let loadedEvents = try await historyService.loadEvents(
                wallet: wallet,
                beforeLt: nil,
                limit: Constants.loadLimit
            )
            let historyEvents = loadedEvents.events.map(HistoryEvent.tonAccountEvent)
            try? HistoryListTonEventsCacheProvider(historyService: historyService)
                .setCache(events: historyEvents, wallet: wallet)
            return filteredTonHistoryEvents(historyEvents)
        case let .jetton(wallet, jettonMasterAddress):
            let loadedEvents = try await historyService.loadEvents(
                wallet: wallet,
                jettonMasterAddress: jettonMasterAddress,
                beforeLt: nil,
                limit: Constants.loadLimit
            )
            let historyEvents = loadedEvents.events.map(HistoryEvent.tonAccountEvent)
            try? HistoryListJettonEventsCacheProvider(
                jettonMasterAddress: jettonMasterAddress,
                historyService: historyService
            ).setCache(events: historyEvents, wallet: wallet)
            return historyEvents
        case let .tronUSDT(wallet):
            guard let tronAddress = wallet.tron?.address else {
                return []
            }
            let tronEvents = try await tronUsdtApi.loadAllTronEvents(
                wallet: wallet,
                events: [],
                address: tronAddress,
                limit: Constants.loadLimit,
                startTimestamp: nil,
                finishTimestamp: nil
            )
            let historyEvents = tronEvents.map(HistoryEvent.tronEvent)
            try? HistoryListTronEventsCacheProvider(historyService: tronUSDTHistoryService)
                .setCache(events: historyEvents, wallet: wallet)
            return historyEvents
        case let .tronTRX(wallet):
            guard let tronAddress = wallet.tron?.address else {
                return []
            }
            let transfers = try await tronUsdtApi.loadTRXTransfers(
                address: tronAddress,
                limit: Constants.loadLimit,
                startTimestamp: nil
            )
            let historyEvents = transfers.map(HistoryEvent.tronEvent)
            do {
                try HistoryListTronEventsCacheProvider(historyService: tronTRXHistoryService)
                    .setCache(events: historyEvents, wallet: wallet)
            } catch {
                Log.w("TRX history cache write failed: \(error)")
            }
            return historyEvents
        }
    }

    func filterTonEvents(_ events: [AccountEvent]) -> [AccountEvent] {
        events.compactMap { event in
            let filteredActions = event.actions.compactMap { action -> AccountEventAction? in
                guard case .tonTransfer = action.type else {
                    return nil
                }
                return action
            }

            guard !filteredActions.isEmpty else {
                return nil
            }

            return AccountEvent(
                eventId: event.eventId,
                date: event.date,
                account: event.account,
                isScam: event.isScam,
                isInProgress: event.isInProgress,
                extra: event.extra,
                excess: event.excess,
                progress: event.progress,
                actions: filteredActions
            )
        }
    }

    func filteredTonHistoryEvents(_ events: [HistoryEvent]) -> [HistoryEvent] {
        let tonEvents = events.compactMap { event -> AccountEvent? in
            guard case let .tonAccountEvent(accountEvent) = event else {
                return nil
            }
            return accountEvent
        }

        return filterTonEvents(tonEvents).map(HistoryEvent.tonAccountEvent)
    }

    func makePreview(
        events: [HistoryEvent],
        context: TradeAssetHistoryContext
    ) -> TradeAssetDetailsHistoryPreview {
        var items = [TradeAssetDetailsHistoryPreview.Item]()

        for event in events {
            switch (event, context) {
            case let (.tonAccountEvent(accountEvent), .ton(wallet)),
                 let (.tonAccountEvent(accountEvent), .jetton(wallet, _)):
                for (actionIndex, eventAction) in accountEvent.actions.enumerated() {
                    guard let item = mapTonPreviewItem(
                        event: accountEvent,
                        actionIndex: actionIndex,
                        action: eventAction,
                        wallet: wallet
                    ) else {
                        continue
                    }

                    items.append(item)
                    guard items.count < Constants.previewLimit else {
                        break
                    }
                }
            case let (.tronEvent(tronTransaction), .tronUSDT(wallet)),
                 let (.tronEvent(tronTransaction), .tronTRX(wallet)):
                if let item = mapTronPreviewItem(
                    event: tronTransaction,
                    wallet: wallet
                ) {
                    items.append(item)
                }
            default:
                break
            }

            guard items.count < Constants.previewLimit else {
                break
            }
        }

        return TradeAssetDetailsHistoryPreview(
            context: context,
            items: items
        )
    }

    func mapTonPreviewItem(
        event: AccountEvent,
        actionIndex: Int,
        action eventAction: AccountEventAction,
        wallet: Wallet
    ) -> TradeAssetDetailsHistoryPreview.Item? {
        let singleActionEvent = AccountEvent(
            eventId: event.eventId,
            date: event.date,
            account: event.account,
            isScam: event.isScam,
            isInProgress: event.isInProgress,
            extra: event.extra,
            excess: event.excess,
            progress: event.progress,
            actions: [eventAction]
        )
        let mappedEvent = mapAccountEventModel(
            event: singleActionEvent,
            wallet: wallet
        )
        guard let action = mappedEvent.actions.first else {
            return nil
        }

        let title: String = {
            if let progress = event.progress, progress > 0, progress < 1 {
                return TKLocales.ActionTypes.pending
            }

            return HistoryListAccountEventActionContentProvider().title(
                actionType: action.eventType,
                customName: action.customName
            )
        }()

        let subtitle = action.leftTopDescription ?? action.leftBottomDescription ?? ""
        let amountText = action.amount ?? action.subamount ?? ""
        let dateText = action.rightTopDescription ?? ""

        return TradeAssetDetailsHistoryPreview.Item(
            id: "\(event.eventId)#\(actionIndex)",
            icon: .init(
                image: icon(for: action)
            ),
            title: title,
            subtitle: subtitle,
            amountText: amountText,
            amountStyle: amountStyle(
                for: action.eventType,
                isPending: event.isInProgress
                    || ((event.progress ?? 0) > 0 && (event.progress ?? 0) < 1)
            ),
            dateText: dateText,
            selection: .ton(
                wallet: wallet,
                event: AccountEventDetailsEvent(
                    accountEvent: event,
                    action: eventAction
                )
            )
        )
    }

    func mapTronPreviewItem(
        event: TronTransaction,
        wallet: Wallet
    ) -> TradeAssetDetailsHistoryPreview.Item? {
        guard let ownerAddress = wallet.tron?.address else {
            return nil
        }

        let eventType = event.getTransactionType(address: ownerAddress)
        let title: String = {
            guard !event.isPending else {
                return TKLocales.ActionTypes.pending
            }

            switch eventType {
            case .send:
                return TKLocales.ActionTypes.sent
            case .receive:
                return TKLocales.ActionTypes.received
            }
        }()

        let subtitle: String = {
            switch eventType {
            case .send:
                return event.toAccount.shortBase58
            case .receive:
                return event.fromAccount.shortBase58
            }
        }()

        let dateText = formattedDate(for: Date(timeIntervalSince1970: TimeInterval(event.timestamp)))
        let amountText = signedAmountFormatter.format(
            amount: event.amount,
            fractionDigits: event.token.fractionDigits,
            accessory: .tokenSymbol(event.token.symbol),
            isNegative: eventType == .send
        )

        let icon: UIImage = switch eventType {
        case .send:
            .TKUIKit.Icons.Size28.trayArrowUp
        case .receive:
            .TKUIKit.Icons.Size28.trayArrowDown
        }

        return TradeAssetDetailsHistoryPreview.Item(
            id: event.txID,
            icon: .init(
                image: icon
            ),
            title: title,
            subtitle: subtitle,
            amountText: amountText,
            amountStyle: event.isPending
                ? .secondary
                : (eventType == .receive ? .positive : .primary),
            dateText: dateText,
            selection: .tron(wallet: wallet, event: event)
        )
    }

    func mapAccountEventModel(
        event: AccountEvent,
        wallet: Wallet
    ) -> AccountEventModel {
        dateFormatter.dateFormat = dateFormat(for: event.date)
        let rightTopDescriptionProvider = HistoryAccountEventRightTopDescriptionProvider(
            dateFormatter: dateFormatter
        )

        return accountEventMapper.mapEvent(
            event,
            nftManagmentStore: walletNFTsManagementStoreProvider(wallet),
            eventDate: event.date,
            accountEventRightTopDescriptionProvider: rightTopDescriptionProvider,
            network: wallet.network,
            nftProvider: { _ in nil },
            decryptedCommentProvider: { _ in nil }
        )
    }

    func dateFormat(for date: Date) -> String {
        let currentDate = Date()
        let calendar = Calendar.current

        if calendar.isDateInToday(date)
            || calendar.isDateInYesterday(date)
            || calendar.isDate(date, equalTo: currentDate, toGranularity: .month)
        {
            return "HH:mm"
        } else if calendar.isDate(date, equalTo: currentDate, toGranularity: .year) {
            return "dd MMM, HH:mm"
        } else {
            return "dd MMM yyyy, HH:mm"
        }
    }

    func formattedDate(for date: Date) -> String {
        dateFormatter.dateFormat = dateFormat(for: date)
        return dateFormatter.string(from: date)
    }

    func icon(for action: AccountEventModel.Action) -> UIImage {
        switch action.stakingImplementation {
        case .liquidTF:
            return .TKUIKit.Icons.Size44.tonStakersLogo
        case .whales:
            return .TKUIKit.Icons.Size44.tonWhalesLogo
        case .tf:
            return .TKUIKit.Icons.Size44.tonNominatorsLogo
        case .unknown, .none:
            return action.eventType.icon ?? .TKUIKit.Icons.Size28.gear
        }
    }

    func amountStyle(
        for eventType: AccountEventModel.Action.ActionType,
        isPending: Bool
    ) -> TKUIKit.TransactionCellContent.AmountStyle {
        guard !isPending else {
            return .secondary
        }

        switch eventType {
        case .receieved, .mint, .bounced, .withdrawStake, .jettonSwap:
            return .positive
        case .spam, .withdrawStakeRequest:
            return .secondary
        case .sent,
             .depositStake,
             .subscribed,
             .unsubscribed,
             .walletInitialized,
             .nftCollectionCreation,
             .nftCreation,
             .removalFromSale,
             .nftPurchase,
             .purchase,
             .bid,
             .putUpForAuction,
             .endOfAuction,
             .contractExec,
             .putUpForSale,
             .burn,
             .domainRenew,
             .unknown:
            return .primary
        }
    }

    enum Constants {
        static let loadLimit = 20
        static let previewLimit = 3
    }
}
