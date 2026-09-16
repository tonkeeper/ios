import SwiftUI
import TKLocalize
import TKUIKit

struct BulletsInfoPopupContent {
    let title: String
    let caption: String
    let bullets: [String]
    let captionStyle: TKTextStyle
    let primaryButtonTitle: String
    let cancelButtonTitle: String?

    init(
        title: String,
        caption: String,
        captionStyle: TKTextStyle,
        bullets: [String],
        primaryButtonTitle: String = TKLocales.Actions.ok,
        cancelButtonTitle: String? = nil
    ) {
        self.title = title
        self.caption = caption
        self.captionStyle = captionStyle
        self.bullets = bullets
        self.primaryButtonTitle = primaryButtonTitle
        self.cancelButtonTitle = cancelButtonTitle
    }
}

struct BulletsInfoPopupView: View {
    let content: BulletsInfoPopupContent
    let onPrimaryTap: () -> Void
    let onCancelTap: (() -> Void)?

    init(
        content: BulletsInfoPopupContent,
        onPrimaryTap: @escaping () -> Void,
        onCancelTap: (() -> Void)? = nil
    ) {
        self.content = content
        self.onPrimaryTap = onPrimaryTap
        self.onCancelTap = onCancelTap
    }

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: Layout.titleSpacing) {
                Text(content.title)
                    .textStyle(.h2)
                    .foregroundStyle(.textPrimary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity)

                Text(content.caption)
                    .textStyle(content.captionStyle)
                    .foregroundStyle(.textSecondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity)
            }
            .padding(.top, Layout.titleTopPadding)
            .padding(.horizontal, Layout.titleHorizontalInset)
            .padding(.bottom, Layout.titleBottomInset)

            if !content.bullets.isEmpty {
                VStack(spacing: Layout.bulletSpacing) {
                    ForEach(content.bullets.indices, id: \.self) { index in
                        BulletsInfoPopupBulletRowView(text: content.bullets[index])
                    }
                }
                .padding(.vertical, Layout.listVerticalInset)
                .background(.backgroundContent)
                .clipShape(
                    RoundedRectangle(
                        cornerRadius: Layout.listCornerRadius,
                        style: .continuous
                    )
                )
                .padding(Layout.listInset)
            }

            VStack(spacing: Layout.buttonSpacing) {
                ButtonView(
                    config: .init(
                        title: content.primaryButtonTitle,
                        size: .large,
                        layoutMode: .fill,
                        appearance: .primary,
                        action: onPrimaryTap
                    )
                )

                if let cancelButtonTitle = content.cancelButtonTitle {
                    ButtonView(
                        config: .init(
                            title: cancelButtonTitle,
                            size: .large,
                            layoutMode: .fill,
                            appearance: .secondary,
                            action: {
                                onCancelTap?()
                            }
                        )
                    )
                }
            }
            .padding([.top, .leading, .trailing], Layout.buttonInset)
            .padding(.bottom, Layout.bottomInset)
        }
        .frame(maxWidth: .infinity, alignment: .top)
        .background(.backgroundPage)
        .ignoresSafeArea(.container, edges: .top)
    }
}

private struct BulletsInfoPopupBulletRowView: View {
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: Layout.contentSpacing) {
            Text("\u{2022}")
                .textStyle(.body2)
                .foregroundStyle(.textPrimary)
                .frame(width: Layout.bulletWidth, alignment: .leading)

            Text(text)
                .textStyle(.body2)
                .foregroundStyle(.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.leading, Layout.leadingInset)
        .padding(.trailing, Layout.trailingInset)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private extension BulletsInfoPopupView {
    enum Layout {
        static let titleTopPadding: CGFloat = 1
        static let titleSpacing: CGFloat = 3
        static let titleHorizontalInset: CGFloat = 32
        static let titleBottomInset: CGFloat = 15
        static let bulletSpacing: CGFloat = 16
        static let listVerticalInset: CGFloat = 20
        static let listCornerRadius: CGFloat = 16
        static let listInset: CGFloat = 16
        static let buttonSpacing: CGFloat = 16
        static let buttonInset: CGFloat = 16
        static let bottomInset: CGFloat = 3
    }
}

private extension BulletsInfoPopupBulletRowView {
    enum Layout {
        static let bulletWidth: CGFloat = 8
        static let contentSpacing: CGFloat = 5
        static let leadingInset: CGFloat = 20
        static let trailingInset: CGFloat = 16
    }
}
