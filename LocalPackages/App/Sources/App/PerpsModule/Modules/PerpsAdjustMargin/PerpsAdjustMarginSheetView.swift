import SwiftUI
import TKLocalize

struct PerpsAdjustMarginSheetView: View {
    let onAdd: () -> Void
    let onReduce: () -> Void

    var body: some View {
        PerpsSheetRowList(rows: [
            PerpsSheetRow(
                icon: .TKUIKit.Icons.Size28.plusCircle,
                title: TKLocales.Perps.AdjustMargin.add,
                description: TKLocales.Perps.AdjustMargin.addDescription,
                accessory: .chevron,
                action: onAdd
            ),
            PerpsSheetRow(
                icon: .TKUIKit.Icons.Size28.minusCircle,
                title: TKLocales.Perps.AdjustMargin.reduce,
                description: TKLocales.Perps.AdjustMargin.reduceDescription,
                accessory: .chevron,
                action: onReduce
            ),
        ])
    }
}
