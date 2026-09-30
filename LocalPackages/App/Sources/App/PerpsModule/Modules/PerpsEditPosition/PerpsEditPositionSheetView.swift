import KeeperCore
import SwiftUI
import TKLocalize

struct PerpsEditPositionSheetView: View {
    let side: PerpsTradeSide
    let onAdd: () -> Void
    let onReduce: () -> Void

    var body: some View {
        PerpsSheetRowList(rows: [
            PerpsSheetRow(
                icon: .TKUIKit.Icons.Size28.plusCircle,
                title: TKLocales.Perps.EditPosition.add,
                description: TKLocales.Perps.EditPosition.addDescription(sideText),
                accessory: .chevron,
                action: onAdd
            ),
            PerpsSheetRow(
                icon: .TKUIKit.Icons.Size28.minusCircle,
                title: TKLocales.Perps.EditPosition.reduce,
                description: TKLocales.Perps.EditPosition.reduceDescription,
                accessory: .chevron,
                action: onReduce
            ),
        ])
    }

    private var sideText: String {
        (side == .long ? TKLocales.Perps.Asset.long : TKLocales.Perps.Asset.short).lowercased()
    }
}
