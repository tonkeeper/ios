import AppUI
import SwiftUI
import TKUIKit

struct PerpsFundingAssetSheetView: View {
    @StateObject private var model: PerpsFundingAssetSheetModel
    let selected: PerpsFundingAssetRow
    let loadIcon: (@MainActor (String) async -> URL?)?
    let onSelect: (PerpsFundingAssetRow) -> Void

    init(
        assets: [PerpsFundingAssetRow],
        selected: PerpsFundingAssetRow,
        loadIcon: (@MainActor (String) async -> URL?)? = nil,
        onSelect: @escaping (PerpsFundingAssetRow) -> Void
    ) {
        _model = StateObject(wrappedValue: PerpsFundingAssetSheetModel(assets: assets))
        self.selected = selected
        self.loadIcon = loadIcon
        self.onSelect = onSelect
    }

    var body: some View {
        AssetPickerList(
            rows: model.assets.map { asset in
                asset.pickerRow(
                    id: asset.assetId,
                    accessory: asset.assetId.lowercased() == selected.assetId.lowercased() ? .checkmark : .none
                )
            },
            onSelect: { row in
                guard let asset = model.assets.first(where: { $0.assetId == row.id }) else { return }
                onSelect(asset)
            }
        )
        .padding(.bottom, 16)
        .task {
            if let loadIcon { await model.loadIcons(using: loadIcon) }
        }
    }
}

@MainActor
final class PerpsFundingAssetSheetModel: ObservableObject {
    @Published private(set) var assets: [PerpsFundingAssetRow]

    init(assets: [PerpsFundingAssetRow]) {
        self.assets = assets
    }

    func loadIcons(using loadIcon: @escaping @MainActor (String) async -> URL?) async {
        await withTaskGroup(of: (String, URL?).self) { group in
            for asset in assets where asset.iconURL == nil {
                let id = asset.assetId
                group.addTask { await(id, loadIcon(id)) }
            }
            for await(id, icon) in group {
                guard !Task.isCancelled else { return }
                guard let icon, let index = assets.firstIndex(where: { $0.assetId == id }) else { continue }
                let asset = assets[index]
                assets[index] = PerpsFundingAssetRow(
                    assetId: asset.assetId, symbol: asset.symbol, network: asset.network,
                    iconURL: icon, balanceText: asset.balanceText
                )
            }
        }
    }
}

extension PerpsFundingAssetRow {
    func pickerRow(id: String, accessory: AssetPickerRowState.Accessory) -> AssetPickerRowState {
        AssetPickerRowState(
            id: id,
            icon: .asset(.url(iconURL, chainIcon: network.chainIcon)),
            title: symbol,
            subtitle: balanceText ?? network.displayName,
            accessory: accessory
        )
    }
}
