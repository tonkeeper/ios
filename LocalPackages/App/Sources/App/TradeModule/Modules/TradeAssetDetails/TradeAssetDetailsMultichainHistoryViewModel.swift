import Combine
import Foundation
import KeeperCore
import TKLogging
import TKUIKit
import UIKit

struct TradeAssetDetailsMultichainHistoryPreview {
    let multichainState: MultichainWalletState
    let activities: [MultichainActivity]
    let items: [MultichainHistoryActivityItem]
}

@MainActor
protocol TradeAssetDetailsMultichainHistoryViewModeling: AnyObject {
    var statePublisher: AnyPublisher<TradeAssetDetailsMultichainHistoryPreview?, Never> { get }
    func scheduleUpdate()
}

@MainActor
final class TradeAssetDetailsMultichainHistoryViewModel: ObservableObject, TradeAssetDetailsMultichainHistoryViewModeling {
    @Published private(set) var state: TradeAssetDetailsMultichainHistoryPreview?

    var statePublisher: AnyPublisher<TradeAssetDetailsMultichainHistoryPreview?, Never> {
        $state.eraseToAnyPublisher()
    }

    private let assetId: String
    private let multichainState: MultichainWalletState
    private let multichainService: MultichainService
    private let itemMapper: MultichainHistoryActivityItemMapper

    private var task: Task<Void, Never>?
    private var decryptionObservation: AnyCancellable?

    init(
        assetId: String,
        multichainState: MultichainWalletState,
        multichainService: MultichainService,
        realtimeManager: MultichainRealtimeManager,
        amountFormatter: AmountFormatter,
        dateFormatter: DateFormatter,
        encryptedComments: MultichainEncryptedComments? = nil
    ) {
        self.assetId = assetId
        self.multichainState = multichainState
        self.multichainService = multichainService
        self.itemMapper = MultichainHistoryActivityItemMapper(
            amountFormatter: amountFormatter,
            dateFormatter: dateFormatter,
            timeStyle: .dateAndTime,
            hidesAmounts: { false },
            encryptedComments: encryptedComments
        )
        decryptionObservation = encryptedComments?.$revision
            .dropFirst()
            .sink { [weak self] _ in
                guard let self, let state else { return }
                self.state = makePreview(activities: state.activities)
            }

        realtimeManager.addHistoryInvalidationObserver(self) { observer, walletId in
            Task { @MainActor in
                guard observer.multichainState.walletId == walletId else { return }
                observer.scheduleUpdate()
            }
        }
    }

    deinit {
        task?.cancel()
    }

    func scheduleUpdate() {
        task?.cancel()
        task = Task { [weak self] in
            await self?.reload()
        }
    }
}

private extension TradeAssetDetailsMultichainHistoryViewModel {
    func reload() async {
        let page: MultichainWalletActivitiesPage
        do {
            page = try await multichainService.getWalletActivities(
                state: multichainState,
                limit: Constants.loadLimit,
                cursor: nil,
                assetId: assetId,
                activityTypeFilter: nil,
                hideDust: nil
            )
        } catch {
            Log.i("asset history load failed, skip update, assetId: \(assetId), error: \(error)")
            return
        }
        guard !Task.isCancelled else {
            return
        }
        state = makePreview(activities: page.activities)
    }

    func makePreview(activities: [MultichainActivity]) -> TradeAssetDetailsMultichainHistoryPreview {
        let activities = activities.filter { !$0.isSpam }

        return TradeAssetDetailsMultichainHistoryPreview(
            multichainState: multichainState,
            activities: activities,
            items: itemMapper.makeItems(activities.prefix(Constants.previewLimit))
        )
    }

    enum Constants {
        static let loadLimit = 25
        static let previewLimit = 3
    }
}
