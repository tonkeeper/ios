import KeeperCore
import SwiftUI
import TKLocalize

@MainActor
final class PerpsEditPositionSheetViewModel: ObservableObject {
    let side: KeeperCore.PerpsTradeSide

    var onAdd: (() -> Void)?
    var onReduce: (() -> Void)?

    init(side: KeeperCore.PerpsTradeSide) {
        self.side = side
    }
}

struct PerpsEditPositionSheetView: View {
    @ObservedObject var viewModel: PerpsEditPositionSheetViewModel

    var body: some View {
        PerpsSheetRowList(rows: [
            PerpsSheetRow(
                icon: .TKUIKit.Icons.Size28.plusCircle,
                title: TKLocales.Perps.EditPosition.add,
                description: TKLocales.Perps.EditPosition.addDescription(sideText),
                accessory: .chevron,
                action: { viewModel.onAdd?() }
            ),
            PerpsSheetRow(
                icon: .TKUIKit.Icons.Size28.minusCircle,
                title: TKLocales.Perps.EditPosition.reduce,
                description: TKLocales.Perps.EditPosition.reduceDescription,
                accessory: .chevron,
                action: { viewModel.onReduce?() }
            ),
        ])
    }

    private var sideText: String {
        (viewModel.side == .long ? TKLocales.Perps.Asset.long : TKLocales.Perps.Asset.short).lowercased()
    }
}
