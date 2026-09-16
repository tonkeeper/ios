import SwiftUI
import TKLocalize

struct PerpsOrderTypeSheetView: View {
    @ObservedObject var viewModel: PerpsOrderTypeSheetViewModel

    var body: some View {
        PerpsSheetRowList(rows: [
            PerpsSheetRow(
                icon: .TKUIKit.Icons.Size28.money,
                title: TKLocales.Perps.OrderType.market,
                description: TKLocales.Perps.OrderType.marketDescription,
                accessory: viewModel.selected == .market ? .checkmark : .none,
                action: { viewModel.select(.market) }
            ),
            PerpsSheetRow(
                icon: .TKUIKit.Icons.Size28.saleBadge,
                title: TKLocales.Perps.OrderType.limit,
                description: TKLocales.Perps.OrderType.limitDescription,
                accessory: viewModel.selected == .limit ? .checkmark : .none,
                action: { viewModel.select(.limit) }
            ),
        ])
    }
}
