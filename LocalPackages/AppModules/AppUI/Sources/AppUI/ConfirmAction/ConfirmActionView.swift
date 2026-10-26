import SwiftUI
import TKUIKit
import UIKit

public struct ConfirmActionView: View {
    @Environment(\.tkPalette) private var palette
    private let state: ConfirmActionState
    private let onBack: (() -> Void)?
    private let onClose: () -> Void

    public init(state: ConfirmActionState, onBack: (() -> Void)?, onClose: @escaping () -> Void) {
        self.state = state
        self.onBack = onBack
        self.onClose = onClose
    }

    public var body: some View {
        VStack(spacing: 0) {
            navBar
            ScrollView {
                VStack(spacing: 0) {
                    header
                    titleBlock
                    rowsCard
                    notice
                    if let footer = state.footer {
                        footer
                            .padding(.top, Layout.spacing)
                    }
                }
                .padding(.horizontal, Layout.inset)
                .padding(.top, Layout.contentTopPadding)
                .padding(.bottom, Layout.spacing)
            }
            .tkImmediateButtonPresses()
            ConfirmActionBar(state: state.action)
                .frame(height: ConfirmActionBar.height)
                .padding(.horizontal, Layout.inset)
        }
        .background(.backgroundPage)
    }

    private var navBar: some View {
        DefaultModalCardHeader(config: .init(
            leftIcon: onBack.map { onBack in
                .init(image: .TKUIKit.Icons.Size16.chevronLeft, size: 16, padding: 8, onTap: { _ in onBack() })
            },
            rightIcon: .close { _ in onClose() }
        ))
    }

    @ViewBuilder
    private var header: some View {
        switch state.header {
        case let .avatar(source, shape):
            AssetAvatarView(imageSource: source, size: .extraLarge, shape: shape)
                .padding(.bottom, Layout.iconBottomPadding)
        case let .letter(letter):
            Text(letter)
                .textStyle(.h2)
                .foregroundStyle(.textPrimary)
                .frame(width: Layout.iconSize, height: Layout.iconSize)
                .background(.backgroundContentTint)
                .clipShape(Circle())
                .padding(.bottom, Layout.iconBottomPadding)
        case let .custom(view):
            view
                .padding(.bottom, Layout.titleBottomPadding)
        }
    }

    @ViewBuilder
    private var titleBlock: some View {
        if state.caption != nil || state.title != nil {
            VStack(spacing: 0) {
                if let caption = state.caption {
                    Text(caption)
                        .textStyle(.body1)
                        .foregroundStyle(.textSecondary)
                        .lineLimit(1)
                }
                if let title = state.title {
                    titleText(title)
                        .textStyle(.h3)
                        .lineLimit(1)
                }
            }
            .multilineTextAlignment(.center)
            .padding(.horizontal, Layout.inset)
            .padding(.bottom, Layout.titleBottomPadding)
        }
    }

    private func titleText(_ title: String) -> Text {
        let text = Text(title).foregroundColor(palette.text.primary)
        guard let suffix = state.titleSuffix else { return text }
        return text + Text(" \(suffix)").foregroundColor(palette.text.tertiary)
    }

    private var rowsCard: some View {
        VStack(spacing: 0) {
            ForEach(Array(state.rows.enumerated()), id: \.element.id) { index, row in
                if index > 0 {
                    Divider()
                        .overlay(palette.separator.common)
                        .padding(.leading, Layout.inset)
                }
                ConfirmActionRowView(row: row)
            }
        }
        .background(.backgroundContent)
        .clipShape(RoundedRectangle(cornerRadius: Layout.cornerRadius))
    }

    @ViewBuilder
    private var notice: some View {
        if let notice = state.notice {
            Text(notice.text)
                .textStyle(.body2)
                .foregroundStyle(notice.isError ? .accentRed : notice.isWarning ? .accentOrange : .textSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, Layout.inset)
                .padding(.top, Layout.noticeTopPadding)
        }
    }
}

struct ConfirmActionRowView: View {
    @Environment(\.tkPalette) private var palette
    let row: ConfirmActionRow

    var body: some View {
        switch row.interaction {
        case .none:
            content(showsChevron: false)
        case let .tap(action, showsChevron):
            Button(action: action) { content(showsChevron: showsChevron) }
                .buttonStyle(.plain)
                .disabled(!row.isEnabled)
                .accessibilityIdentifier("confirm_row_" + row.id)
        case let .hint(text):
            HintButton(configuration: Self.hintConfiguration) { direction in
                TKTooltipView(configuration: .init(title: text, lineLimit: nil), position: direction)
            } label: {
                content(showsChevron: false)
            }
        }
    }

    private func content(showsChevron: Bool) -> some View {
        HStack(alignment: .top, spacing: Layout.rowSpacing) {
            title
                .layoutPriority(1)
            Spacer(minLength: 0)
            value
            if showsChevron {
                SwiftUI.Image(uiImage: .TKUIKit.Icons.Size16.chevronRight)
                    .foregroundStyle(.iconTertiary)
                    .padding(.top, Layout.chevronTopPadding)
            }
        }
        .padding(.horizontal, Layout.inset)
        .padding(.vertical, Layout.rowVerticalPadding)
        .contentShape(Rectangle())
    }

    @ViewBuilder
    private var title: some View {
        let titleText = Text(row.title)
            .textStyle(.body1)
            .foregroundStyle(.textSecondary)
            .lineLimit(1)
        if let hint = row.titleHint {
            HStack(spacing: Layout.titleHintSpacing) {
                titleText
                HintButton(configuration: Self.titleHintConfiguration) { direction in
                    TKHintTextView(text: hint, position: direction)
                } label: {
                    SwiftUI.Image(uiImage: .TKUIKit.Icons.Size16.informationCircle)
                        .renderingMode(.template)
                        .foregroundStyle(.iconSecondary)
                }
            }
        } else {
            titleText
        }
    }

    @ViewBuilder
    private var value: some View {
        switch row.value {
        case let .text(text, subtitle, tone):
            valueStack(subtitle: subtitle) {
                Text(text)
                    .textStyle(.label1)
                    .foregroundColor(color(tone))
                    .multilineTextAlignment(.trailing)
            }
        case let .parts(parts, subtitle):
            valueStack(subtitle: subtitle) {
                parts.reduce(Text("")) { $0 + Text($1.text).foregroundColor(color($1.tone)) }
                    .textStyle(.label1)
                    .multilineTextAlignment(.trailing)
            }
        case let .wallet(name, emoji, icon):
            HStack(spacing: Layout.walletIconSpacing) {
                if let emoji {
                    Text(emoji).textStyle(.label1)
                } else if let icon {
                    SwiftUI.Image(uiImage: icon)
                        .renderingMode(.template)
                        .foregroundStyle(.iconPrimary)
                }
                Text(name)
                    .textStyle(.label1)
                    .foregroundStyle(.textPrimary)
                    .lineLimit(1)
            }
        case let .feeOption(text, token, showsPicker):
            HStack(spacing: Layout.pickerSpacing) {
                feeText(text, token: token)
                    .textStyle(.label1)
                    .lineLimit(1)
                if showsPicker {
                    SwiftUI.Image(uiImage: .TKUIKit.Icons.Size16.switch)
                        .renderingMode(.template)
                        .foregroundStyle(.textAccent)
                }
            }
        case let .unavailable(text, retryTitle, retry):
            HStack(spacing: Layout.pickerSpacing) {
                Text(text)
                    .textStyle(.label1)
                    .foregroundStyle(.textSecondary)
                    .lineLimit(1)
                Button(action: retry) {
                    HStack(spacing: Layout.pickerSpacing) {
                        Text(retryTitle).textStyle(.label1)
                        SwiftUI.Image(uiImage: .TKUIKit.Icons.Size16.refresh)
                            .renderingMode(.template)
                    }
                    .foregroundStyle(.textAccent)
                }
                .buttonStyle(.plain)
            }
        case .loading:
            ShimmerSwiftUIView(config: .init(color: .backgroundContentTint, cornerRadius: .value(Layout.shimmerCornerRadius)))
                .frame(width: Layout.shimmerWidth, height: Layout.shimmerHeight)
                .padding(.top, Layout.shimmerTopPadding)
        }
    }

    private func valueStack(subtitle: String?, @ViewBuilder top: () -> some View) -> some View {
        VStack(alignment: .trailing, spacing: Layout.subtitleSpacing) {
            top()
            if let subtitle {
                Text(subtitle)
                    .textStyle(.body2)
                    .foregroundStyle(.textSecondary)
                    .multilineTextAlignment(.trailing)
            }
        }
    }

    private func feeText(_ text: String, token: String?) -> Text {
        let value = Text(text).foregroundColor(palette.text.primary)
        guard let token else { return value }
        return value + Text(" · \(token)").foregroundColor(palette.text.accent)
    }

    private func color(_ tone: ConfirmActionRow.Tone) -> Color {
        switch tone {
        case .primary: palette.text.primary
        case .positive: palette.accent.green
        case .negative: palette.accent.red
        case .tertiary: palette.text.tertiary
        case .accent: palette.text.accent
        }
    }

    private static let titleHintConfiguration = HintConfiguration(
        position: HintPosition(
            tailParameters: TKHintTextView.tailParameters,
            horizontal: .default,
            vertical: .init(absolute: 1),
            direction: .bottomLeft
        ),
        maximumWidth: 280,
        animationStyle: .bouncing
    )

    private static let hintConfiguration = HintConfiguration(
        position: HintPosition(
            tailParameters: TKTooltipView.tailParameters,
            horizontal: .default,
            vertical: .init(absolute: 0),
            direction: .topCenter
        ),
        maximumWidth: 260,
        animationStyle: .bouncing
    )
}

private enum Layout {
    static let inset: CGFloat = 16
    static let spacing: CGFloat = 16
    static let cornerRadius: CGFloat = 16
    static let iconSize: CGFloat = 96
    static let contentTopPadding: CGFloat = 4
    static let iconBottomPadding: CGFloat = 18
    static let titleBottomPadding: CGFloat = 30
    static let rowVerticalPadding: CGFloat = 14
    static let rowSpacing: CGFloat = 8
    static let subtitleSpacing: CGFloat = -2
    static let chevronTopPadding: CGFloat = 6
    static let noticeTopPadding: CGFloat = 12
    static let walletIconSpacing: CGFloat = 4
    static let titleHintSpacing: CGFloat = 4
    static let pickerSpacing: CGFloat = 4
    static let shimmerWidth: CGFloat = 80
    static let shimmerHeight: CGFloat = 20
    static let shimmerTopPadding: CGFloat = 2
    static let shimmerCornerRadius: CGFloat = 8
}
