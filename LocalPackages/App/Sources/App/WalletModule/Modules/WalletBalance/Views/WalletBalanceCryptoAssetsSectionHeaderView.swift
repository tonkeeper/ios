import SwiftUI
import TKLocalize
import TKUIKit

struct WalletBalanceCryptoAssetsSectionHeaderView: View {
    let canManage: Bool
    let onTapOpenAssets: () -> Void
    let onTapManage: () -> Void
    var body: some View {
        HStack(alignment: .center, spacing: 0) {
            Button(action: onTapOpenAssets) {
                HStack(spacing: 2) {
                    Text(TKLocales.Trade.Assets.title)
                        .textStyle(.label1)
                        .foregroundStyle(.textPrimary)
                    SwiftUI.Image.TKUIKit.Icons.Size16.chevronRight
                        .resizable()
                        .scaledToFit()
                        .frame(width: 16, height: 16)
                        .foregroundStyle(.iconSecondary)
                }
            }
            .buttonStyle(.plain)

            Spacer(minLength: 12)

            if canManage {
                Button(action: onTapManage) {
                    HStack(spacing: 6) {
                        Text(TKLocales.WalletBalanceList.ManageButton.title)
                            .textStyle(.label2)
                            .foregroundStyle(.textSecondary)
                        SwiftUI.Image.TKUIKit.Icons.Size16.sliders
                            .resizable()
                            .scaledToFit()
                            .frame(width: 16, height: 16)
                            .foregroundStyle(.iconSecondary)
                    }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 10)
    }
}
