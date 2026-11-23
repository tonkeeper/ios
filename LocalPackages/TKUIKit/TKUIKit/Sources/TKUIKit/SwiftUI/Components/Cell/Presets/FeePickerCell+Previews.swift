import SwiftUI
import UIKit

@available(iOS 17.0, *)
#Preview("States", traits: .sizeThatFitsLayout) {
    let battery = FeePickerCellContent.Leading.icon(
        image: UIImage.TKUIKit.Icons.Size24.flash,
        tintColor: .accentGreen,
        backgroundColor: TKColor.accentGreen.opacity(0.12)
    )
    VStack(spacing: 0) {
        FeePickerCell(
            config: .content(FeePickerCellContent(
                leading: battery,
                title: "Battery",
                subtitle: "50 charges · 771 available",
                isSelected: true
            )),
            showsDivider: true
        )
        FeePickerCell(
            config: .content(FeePickerCellContent(
                leading: battery,
                title: "Battery",
                subtitle: "258 charges",
                isDisabled: true,
                subtitleWarning: "Not enough",
                subtitleActionTitle: "Top up"
            )),
            showsDivider: true
        )
        FeePickerCell(
            config: .content(FeePickerCellContent(
                leading: battery,
                title: "TRX",
                subtitle: "≈ $2.15 · 8.1 TRX",
                isDisabled: true,
                subtitleActionTitle: "Deposit"
            ))
        )
    }
    .asCellsGroup()
    .padding(.vertical, 16)
    .background(.backgroundPage)
    .tkPreviewTheme(.deepBlue)
}
