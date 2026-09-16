import SwiftUI
import TKUIKit

struct BatteryFeeShortagePopupContent {
    let title: String
    let caption: String
    let rechargeButtonTitle: String
    let depositButtonTitle: String
}

struct BatteryFeeShortagePopupView: View {
    let content: BatteryFeeShortagePopupContent
    let onRecharge: () -> Void
    let onDeposit: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            BatterySwiftUIView(
                config: BatterySwiftUIViewConfig(
                    size: .size128,
                    state: .emptyTinted,
                    padding: BatterySwiftUIViewConfig.Padding(
                        top: Layout.iconTopInset,
                        bottom: Layout.iconBottomInset
                    )
                )
            )
            .padding(.bottom, Layout.iconBlockBottomInset)

            VStack(spacing: Layout.textSpacing) {
                Text(content.title)
                    .textStyle(.h2)
                    .foregroundStyle(.textPrimary)

                Text(content.caption)
                    .textStyle(.body1)
                    .foregroundStyle(.textSecondary)
            }
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, Layout.textHorizontalInset)
            .padding(.bottom, Layout.textBottomInset)

            VStack(spacing: Layout.buttonsSpacing) {
                ButtonView(
                    config: ButtonView.Config(
                        title: content.rechargeButtonTitle,
                        size: .large,
                        layoutMode: .fill,
                        appearance: .primary,
                        action: onRecharge
                    )
                )

                ButtonView(
                    config: ButtonView.Config(
                        title: content.depositButtonTitle,
                        size: .large,
                        layoutMode: .fill,
                        appearance: .secondary,
                        action: onDeposit
                    )
                )
            }
            .padding(.top, Layout.buttonsTopInset)
            .padding(.horizontal, Layout.buttonsHorizontalInset)
            .padding(.bottom, Layout.buttonsBottomInset)
        }
        .frame(maxWidth: .infinity, alignment: .top)
        .background(.backgroundPage)
    }
}

private extension BatteryFeeShortagePopupView {
    enum Layout {
        /// The design frames the 68×114 battery in a 128pt box, and measures the spacing below the
        /// icon from that box rather than from the artwork.
        static let iconTopInset: CGFloat = 6
        static let iconBottomInset: CGFloat = 8
        static let iconBlockBottomInset: CGFloat = 16
        static let textSpacing: CGFloat = 4
        static let textHorizontalInset: CGFloat = 32
        static let textBottomInset: CGFloat = 16
        static let buttonsTopInset: CGFloat = 16
        static let buttonsHorizontalInset: CGFloat = 16
        static let buttonsBottomInset: CGFloat = 2
        static let buttonsSpacing: CGFloat = 16
    }
}
