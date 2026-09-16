import SwiftUI
import TKLocalize
import TKUIKit

struct RampOnLayoutLoadErrorCell: View {
    let onRetry: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: Constants.iconTitleSpacing) {
            iconView

            Text(TKLocales.Ramp.List.loadErrorBannerTitle)
                .textStyle(.label2)
                .foregroundStyle(.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)

            retryButton
        }
        .padding(16)
    }
}

private extension RampOnLayoutLoadErrorCell {
    var iconView: some View {
        SwiftUI.Image.TKUIKit.Icons.Size32.exclamationmarkCircle
            .renderingMode(.template)
            .resizable()
            .scaledToFit()
            .foregroundStyle(.iconSecondary)
            .frame(width: 24, height: 24)
            .frame(width: 44, height: 44)
            .background(.backgroundContentTint)
            .clipShape(Circle())
    }

    var retryButton: some View {
        ButtonView(
            config: .init(
                title: showsRetryTitle ? TKLocales.Ramp.List.loadErrorBannerButton : "",
                size: .small,
                appearance: .tertiary,
                icon: .init(
                    image: .TKUIKit.Icons.Size16.refresh,
                    alignment: .leading
                ),
                action: onRetry
            )
        )
        .fixedSize()
    }

    var showsRetryTitle: Bool {
        UIScreen.main.bounds.width > 375
    }

    enum Constants {
        static let iconTitleSpacing: CGFloat = 16
    }
}
