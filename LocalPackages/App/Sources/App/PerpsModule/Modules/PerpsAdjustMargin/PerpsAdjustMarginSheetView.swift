import SwiftUI
import TKLocalize

@MainActor
final class PerpsAdjustMarginSheetViewModel: ObservableObject {
    var onAdd: (() -> Void)?
    var onReduce: (() -> Void)?
}

struct PerpsAdjustMarginSheetView: View {
    @ObservedObject var viewModel: PerpsAdjustMarginSheetViewModel

    var body: some View {
        PerpsSheetRowList(rows: [
            PerpsSheetRow(
                icon: .TKUIKit.Icons.Size28.plusCircle,
                title: TKLocales.Perps.AdjustMargin.add,
                description: TKLocales.Perps.AdjustMargin.addDescription,
                accessory: .chevron,
                action: { viewModel.onAdd?() }
            ),
            PerpsSheetRow(
                icon: .TKUIKit.Icons.Size28.minusCircle,
                title: TKLocales.Perps.AdjustMargin.reduce,
                description: TKLocales.Perps.AdjustMargin.reduceDescription,
                accessory: .chevron,
                action: { viewModel.onReduce?() }
            ),
        ])
    }
}
