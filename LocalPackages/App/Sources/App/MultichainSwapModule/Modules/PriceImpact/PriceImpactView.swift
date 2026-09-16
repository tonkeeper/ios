import SwiftUI
import TKUIKit
import UIKit

struct PriceImpactView: View {
    let presentation: PriceImpactPresentation

    var body: some View {
        VStack(spacing: 0) {
            SwiftUI.Image(uiImage: presentation.style.icon)
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .frame(width: Layout.iconSize, height: Layout.iconSize)
                .foregroundStyle(presentation.style.accentColor)

            Text(presentation.title)
                .textStyle(.h2)
                .foregroundStyle(.textPrimary)
                .multilineTextAlignment(.center)
                .padding(.top, Layout.titleTopPadding)
                .padding(.bottom, Layout.subtitleTopPadding)

            Text(presentation.subtitle)
                .textStyle(.body1)
                .foregroundStyle(.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.bottom, Layout.descriptionTopPadding)

            Text(presentation.description)
                .textStyle(.body1)
                .foregroundStyle(.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.bottom, Layout.buttonsTopPadding)

            VStack(spacing: Layout.buttonsSpacing) {
                ButtonView(
                    config: ButtonView.Config(
                        title: presentation.confirmButtonTitle,
                        size: .large,
                        layoutMode: .fill,
                        appearance: {
                            switch presentation.style {
                            case .warning:
                                .attention
                            case .danger:
                                .destructive
                            }
                        }(),
                        action: presentation.didTapConfirm
                    )
                )

                ButtonView(
                    config: ButtonView.Config(
                        title: presentation.backButtonTitle,
                        size: .large,
                        layoutMode: .fill,
                        appearance: .secondary,
                        action: presentation.didTapBack
                    )
                )
            }
            .padding(.bottom, Layout.buttonsBottomPadding)
        }
        .padding(.horizontal, Layout.horizontalPadding)
        .frame(maxWidth: .infinity, alignment: .top)
        .background(.backgroundPage)
    }
}

private extension PriceImpactView {
    enum Layout {
        static let horizontalPadding: CGFloat = 16
        static let iconSize: CGFloat = 84
        static let titleTopPadding: CGFloat = 13
        static let subtitleTopPadding: CGFloat = 4
        static let descriptionTopPadding: CGFloat = 12
        static let buttonsTopPadding: CGFloat = 30
        static let buttonsBottomPadding: CGFloat = 3
        static let buttonsSpacing: CGFloat = 17
    }
}

private extension PriceImpactPresentationStyle {
    var icon: UIImage {
        switch self {
        case .warning:
            return .TKUIKit.Icons.Size84.exclamationmarkCircle
        case .danger:
            return .TKUIKit.Icons.Size84.exclamationmarkTriangle
        }
    }

    var accentColor: TKColor {
        switch self {
        case .warning:
            return .accentOrange
        case .danger:
            return .accentRed
        }
    }
}
