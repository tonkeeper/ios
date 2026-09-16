import SwiftUI
import TKLocalize
import TKUIKit

final class TooltipViewControllerFactoryImplementation {}

extension TooltipViewControllerFactoryImplementation: TooltipViewControllerFactory {
    func makeHintViewController(
        id: TooltipID,
        direction: HintPosition.Direction?,
        maximumWidth: CGFloat
    ) -> UIViewController {
        let rootView: AnyView
        switch id {
        case .walletBalanceWithdraw:
            rootView = AnyView(
                TKTooltipView(
                    configuration: TKTooltipView.Configuration(
                        title: TKLocales.WalletButtons.sendFromHere,
                        badgeTitle: TKLocales.Common.new
                    ),
                    position: direction
                )
            )
        case .newHistoryEntryPoint:
            rootView = AnyView(
                TKTooltipView(
                    configuration: TKTooltipView.Configuration(
                        title: TKLocales.Tabs.History.hint,
                        badgeTitle: TKLocales.Common.new
                    ),
                    position: direction
                )
            )
        case .tradeTab:
            rootView = AnyView(
                TKTooltipView(
                    configuration: TKTooltipView.Configuration(
                        title: TKLocales.Tabs.Trade.hint,
                        badgeTitle: TKLocales.Common.new
                    ),
                    position: direction
                )
            )
        case .tradeFavorite:
            rootView = AnyView(
                TKTooltipView(
                    configuration: TKTooltipView.Configuration(
                        title: TKLocales.Trade.Favorites.tooltip,
                        badgeTitle: TKLocales.Common.new
                    ),
                    position: direction
                )
            )
        case .addMultichainWalletMain, .addMultichainWalletWalletsList:
            rootView = AnyView(
                TKTooltipView(
                    configuration: TKTooltipView.Configuration(
                        title: TKLocales.tooltipAddMultichainWallet,
                        badgeTitle: TKLocales.Common.new,
                        lineLimit: nil
                    ),
                    position: direction
                )
            )
        }
        let hostingController = TKHostingController(content: rootView)
        hostingController.view.backgroundColor = .clear
        let size = hostingController.sizeThatFits(
            in: CGSize(
                width: maximumWidth,
                height: CGFloat.greatestFiniteMagnitude
            )
        )
        hostingController.preferredContentSize = CGSize(
            width: min(maximumWidth, ceil(size.width)),
            height: ceil(size.height)
        )
        return hostingController
    }
}
