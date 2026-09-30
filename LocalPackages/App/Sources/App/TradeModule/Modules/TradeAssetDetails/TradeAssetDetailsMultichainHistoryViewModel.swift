import Combine
import Foundation
import KeeperCore
import TKLogging
import TKUIKit
import UIKit

struct TradeAssetDetailsMultichainHistoryPreview {
    let multichainState: MultichainWalletState
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

    init(
        assetId: String,
        multichainState: MultichainWalletState,
        multichainService: MultichainService,
        amountFormatter: AmountFormatter,
        dateFormatter: DateFormatter
    ) {
        self.assetId = assetId
        self.multichainState = multichainState
        self.multichainService = multichainService
        self.itemMapper = MultichainHistoryActivityItemMapper(
            amountFormatter: amountFormatter,
            dateFormatter: dateFormatter
        )
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
        let items = activities
            .filter { !$0.isSpam }
            .prefix(Constants.previewLimit)
            .map(itemMapper.makeItem)

        return TradeAssetDetailsMultichainHistoryPreview(
            multichainState: multichainState,
            items: Array(items)
        )
    }

    enum Constants {
        static let loadLimit = 25
        static let previewLimit = 3
    }
}
