import AppUI
import SwiftUI
import TKUIKit

struct PerpsFundingAssetSheetView: View {
    let assets: [PerpsFundingAssetRow]
    let selected: PerpsFundingAssetRow
    let onSelect: (PerpsFundingAssetRow) -> Void

    var body: some View {
        AssetPickerList(
            rows: assets.indices.map { index in
                let asset = assets[index]
                return asset.pickerRow(
                    id: "\(index)",
                    accessory: asset.assetId.lowercased() == selected.assetId.lowercased() ? .checkmark : .none
                )
            },
            onSelect: { row in
                guard let index = Int(row.id), assets.indices.contains(index) else { return }
                onSelect(assets[index])
            }
        )
        .padding(.bottom, 16)
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
