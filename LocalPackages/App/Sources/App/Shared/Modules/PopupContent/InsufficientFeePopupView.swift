import SwiftUI
import TKUIKit

struct InsufficientFeePopupContent {
    /// Which action the blue primary button carries; the grey secondary button carries the other one.
    enum PrimaryAction {
        case deposit
        case continueMigration
    }

    let title: String
    let caption: String
    let description: String?
    let primaryButtonTitle: String
    let secondaryButtonTitle: String?
    let primaryAction: PrimaryAction
    let walletIcon: SwiftUI.Image?
    let walletName: String
    let walletNamePlaceholder: String?

    init(
        title: String,
        caption: String,
        description: String? = nil,
        primaryButtonTitle: String,
        secondaryButtonTitle: String? = nil,
        primaryAction: PrimaryAction = .deposit,
        walletIcon: SwiftUI.Image? = nil,
        walletName: String = "",
        walletNamePlaceholder: String? = nil
    ) {
        self.title = title
        self.caption = caption
        self.description = description
        self.primaryButtonTitle = primaryButtonTitle
        self.secondaryButtonTitle = secondaryButtonTitle
        self.primaryAction = primaryAction
        self.walletIcon = walletIcon
        self.walletName = walletName
        self.walletNamePlaceholder = walletNamePlaceholder
    }
}

struct InsufficientFeePopupView: View {
    let content: InsufficientFeePopupContent
    let onPrimary: () -> Void
    let onSecondary: (() -> Void)?

    @Environment(\.tkPalette) private var palette

    init(
        content: InsufficientFeePopupContent,
        onPrimary: @escaping () -> Void,
        onSecondary: (() -> Void)? = nil
    ) {
        self.content = content
        self.onPrimary = onPrimary
        self.onSecondary = onSecondary
    }

    var body: some View {
        VStack(spacing: 0) {
            SwiftUI.Image(uiImage: .TKUIKit.Icons.Size84.exclamationmarkCircle)
                .renderingMode(.template)
                .foregroundStyle(.iconSecondary)
                .frame(width: Layout.iconSize, height: Layout.iconSize)
                .padding(.bottom, Layout.iconBottomInset)

            VStack(spacing: Layout.textSpacing) {
                titleText
                    .textStyle(.h2)
                    .foregroundStyle(.textPrimary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity)

                Text(content.caption)
                    .textStyle(.body1)
                    .foregroundStyle(.textSecondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity)

                if let description = content.description {
                    Text(description)
                        .textStyle(.body2)
                        .foregroundStyle(.textTertiary)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity)
                }
            }
            .padding(.horizontal, Layout.textHorizontalInset)

            ButtonView(
                config: .init(
                    title: content.primaryButtonTitle,
                    size: .large,
                    layoutMode: .fill,
                    appearance: .primary,
                    action: onPrimary
                )
            )
            .padding(.top, Layout.buttonTopInset)
            .padding(.horizontal, Layout.buttonHorizontalInset)

            if let secondaryButtonTitle = content.secondaryButtonTitle, let onSecondary {
                ButtonView(
                    config: .init(
                        title: secondaryButtonTitle,
                        size: .large,
                        layoutMode: .fill,
                        appearance: .secondary,
                        action: onSecondary
                    )
                )
                .padding(.top, Layout.secondaryButtonTopInset)
                .padding(.horizontal, Layout.buttonHorizontalInset)
            }
        }
        .padding(.bottom, Layout.buttonBottomInset)
        .frame(maxWidth: .infinity, alignment: .top)
        .background(.backgroundPage)
        .ignoresSafeArea(.container, edges: .top)
    }

    private var titleText: Text {
        guard let walletIcon = content.walletIcon,
              let walletNamePlaceholder = content.walletNamePlaceholder,
              let walletNameRange = content.title.range(of: walletNamePlaceholder)
        else {
            return Text(content.title)
        }

        return Text(String(content.title[..<walletNameRange.lowerBound]))
            + Text(walletIcon.renderingMode(.template))
            .baselineOffset(-2)
            .foregroundColor(palette.icon.primary)
            + Text(" \(content.walletName)")
            + Text(String(content.title[walletNameRange.upperBound...]))
    }
}

private extension InsufficientFeePopupView {
    enum Layout {
        static let iconSize: CGFloat = 84
        static let iconBottomInset: CGFloat = 12
        static let textSpacing: CGFloat = 1
        static let textHorizontalInset: CGFloat = 32
        static let buttonTopInset: CGFloat = 28
        static let secondaryButtonTopInset: CGFloat = 12
        static let buttonHorizontalInset: CGFloat = 16
        static let buttonBottomInset: CGFloat = 3
    }
}
