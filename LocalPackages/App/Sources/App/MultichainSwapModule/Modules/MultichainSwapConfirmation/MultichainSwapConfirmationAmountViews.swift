import SwiftUI
import TKUIKit

struct MultichainSwapConfirmationAmountCard: View {
    let label: String
    let amountLine: String
    let tokenAvatarSource: AssetAvatarViewImageSource

    var body: some View {
        HStack(spacing: 12) {
            AssetAvatarView(imageSource: tokenAvatarSource, size: .small)

            VStack(alignment: .leading, spacing: 1) {
                Text(label)
                    .textStyle(.body2)
                    .foregroundStyle(.textSecondary)

                Text(amountLine)
                    .textStyle(.num2)
                    .foregroundStyle(.textPrimary)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .padding(.top, 11)
        .padding(.bottom, 9)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.backgroundContent)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}
