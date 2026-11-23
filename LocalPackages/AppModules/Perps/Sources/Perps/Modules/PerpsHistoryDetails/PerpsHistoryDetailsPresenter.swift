import AppUI
import PerpsModels
import SwiftUI
import TKUIKit
import UIKit

/// One sheet for a position event wherever the history shows it: the asset page, the perps
/// history and the wallet's own history.
@MainActor
public final class PerpsHistoryDetailsPresenter {
    private let marketsStore: any PerpsMarketsStoring
    private let format: PerpsFormatting
    private let shareFlow: PerpsSharePositionFlow
    private let onOpenLoyalty: @MainActor () -> Void

    public convenience init(
        marketsStore: any PerpsMarketsStoring,
        format: PerpsFormatting,
        onOpenLoyalty: @escaping @MainActor () -> Void
    ) {
        self.init(
            marketsStore: marketsStore,
            format: format,
            shareFlow: PerpsSharePositionFlow(format: format),
            onOpenLoyalty: onOpenLoyalty
        )
    }

    init(
        marketsStore: any PerpsMarketsStoring,
        format: PerpsFormatting,
        shareFlow: PerpsSharePositionFlow,
        onOpenLoyalty: @escaping @MainActor () -> Void
    ) {
        self.marketsStore = marketsStore
        self.format = format
        self.shareFlow = shareFlow
        self.onOpenLoyalty = onOpenLoyalty
    }

    public func present(_ event: PerpsHistoryEvent, from presenter: UIViewController) {
        guard presenter.view.window != nil, presenter.presentedViewController == nil else { return }
        weak var bottomSheet: TKBottomSheetViewController?
        let sheet = TKBottomSheetViewController(
            contentViewController: TKBottomSheetScrollHostingController(header: .compact) {
                PerpsHistoryDetailsContent(
                    event: event,
                    marketsStore: marketsStore,
                    format: format,
                    onShare: { [weak self, weak presenter] share in
                        bottomSheet?.dismiss {
                            guard let presenter, presenter.view.window != nil else { return }
                            self?.shareFlow.present(share, from: presenter)
                        }
                    },
                    onOpenLoyalty: { [weak self] in
                        bottomSheet?.dismiss { self?.onOpenLoyalty() }
                    }
                )
            }
        )
        bottomSheet = sheet
        sheet.present(fromViewController: presenter)
    }
}

private struct PerpsHistoryDetailsContent: View {
    let event: PerpsHistoryEvent
    let marketsStore: any PerpsMarketsStoring
    let format: PerpsFormatting
    let onShare: (SharePositionSnapshot) -> Void
    let onOpenLoyalty: () -> Void

    @State private var market: PerpsHistoryDetailsMapping.Market?

    var body: some View {
        MultichainTransactionDetailsView(
            model: PerpsHistoryDetailsMapping.model(
                event: event,
                market: market,
                format: format,
                onShare: PerpsHistoryDetailsMapping.shareSnapshot(event: event, iconURL: market?.iconURL).map { share in
                    { onShare(share) }
                },
                onOpenLoyalty: onOpenLoyalty
            ),
            onOpenTransaction: { _, _ in },
            onCopy: { _ in }
        )
        .task {
            guard let marketId = event.marketId else { return }
            let snapshot = await marketsStore.snapshot(marketId: marketId)
            guard !Task.isCancelled else { return }
            market = snapshot.map { .init(iconURL: $0.iconURL, sizeDecimals: $0.sizeDecimals) }
        }
    }
}
