import SwiftUI
import TKUIKit
import UIKit

struct SettingsListItemCell: View {
    let item: SettingsListItem
    let showsDivider: Bool

    @Environment(\.tkPalette) private var palette
    @State private var anchorView: UIView?

    var body: some View {
        Cell(
            config: Cell.Config(
                showsDivider: showsDivider,
                haptic: haptic,
                action: action
            ),
            leading: {
                if let icon = item.icon {
                    CellAssetLeading {
                        SettingsListItemIconView(icon: icon)
                    }
                }
            },
            center: {
                CellCenter {
                    primaryRow
                } secondaryRow: {
                    if !item.captions.isEmpty {
                        captionsView
                    }
                }
                .frame(minHeight: 56, alignment: .center)
            },
            trailing: {
                trailingView
            }
        )
        .overlay(
            AnchorViewResolver { view in
                anchorView = view
            }
        )
    }
}

private extension SettingsListItemCell {
    var haptic: TKTapAnimationHaptic {
        if case .toggle = item.accessory {
            return .light
        }
        return .none
    }

    var action: (() -> Void)? {
        if case let .toggle(toggle) = item.accessory {
            guard toggle.isEnabled else { return nil }
            return { toggle.onToggle(!toggle.isOn) }
        }
        guard let onTap = item.onTap else { return nil }
        return { onTap(anchorView) }
    }

    var titleText: Text {
        item.title.parts.reduce(Text(verbatim: "")) { result, part in
            switch part {
            case let .text(text):
                result + Text(text)
            case let .icon(icon):
                result + Text(icon.renderingMode(.template))
                    .baselineOffset(-2)
                    .foregroundColor(palette.icon.primary)
            }
        }
    }

    var primaryRow: some View {
        HStack(spacing: 0) {
            titleText
                .textStyle(.label1)
                .foregroundStyle(item.titleColor)
                .lineLimit(1)

            if let inlineCaption = item.inlineCaption {
                Text(inlineCaption)
                    .textStyle(.body2)
                    .foregroundStyle(.textSecondary)
                    .lineLimit(1)
                    .padding(.leading, Layout.inlineCaptionSpacing)
            }

            if !item.tags.isEmpty {
                ForEach(Array(item.tags.enumerated()), id: \.offset) { _, tag in
                    TKTagSwiftUIView(config: tag)
                }
                .padding(.bottom, 2)
            }

            if let redDotColor = item.redDotColor {
                SwiftUI.Image.TKUIKit.Icons.Size12.redDot
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
                    .foregroundStyle(redDotColor)
                    .frame(width: Layout.redDotSize, height: Layout.redDotSize)
                    .padding(.leading, Layout.redDotSpacing)
            }

            Spacer(minLength: 0)
        }
    }

    var captionsView: some View {
        VStack(alignment: .leading, spacing: Layout.captionSpacing) {
            ForEach(Array(item.captions.enumerated()), id: \.offset) { _, caption in
                Text(caption.text)
                    .textStyle(.body2)
                    .foregroundStyle(caption.color)
                    .lineLimit(caption.lineLimit)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    @ViewBuilder
    var trailingView: some View {
        switch item.accessory {
        case .none:
            EmptyView()
        case .chevron:
            CellTrailingAccessory(
                config: CellTrailingAccessory.Config(
                    color: .iconTertiary,
                    icon: SwiftUI.Image.TKUIKit.Icons.Size16.chevronRight,
                    iconSize: 16
                )
            )
        case let .icon(image, tintColor):
            CellTrailingAccessory(
                config: CellTrailingAccessory.Config(
                    color: tintColor,
                    icon: SwiftUI.Image(uiImage: image)
                )
            )
        case let .text(text):
            textAccessoryView(text)
        case let .menu(menu):
            Menu {
                ForEach(Array(menu.options.enumerated()), id: \.offset) { _, option in
                    Button(action: option.action) {
                        if option.isSelected {
                            Label(option.title, systemImage: "checkmark")
                        } else {
                            Text(option.title)
                        }
                    }
                }
            } label: {
                textAccessoryView(menu.label)
            }
        case let .toggle(toggle):
            SettingsListItemToggleView(toggle: toggle)
        }
    }

    func textAccessoryView(_ text: SettingsListItemTextAccessory) -> some View {
        Text(text.text)
            .textStyle(text.textStyle)
            .foregroundStyle(text.color)
            .lineLimit(text.lineLimit)
            .multilineTextAlignment(.trailing)
            .padding(.trailing, Layout.trailingInset)
    }

    enum Layout {
        static let inlineCaptionSpacing: CGFloat = 4
        static let captionSpacing: CGFloat = -3
        static let redDotSize: CGFloat = 12
        static let redDotSpacing: CGFloat = 4
        static let trailingInset: CGFloat = 16
    }
}

private struct SettingsListItemIconView: View {
    let icon: SettingsListItemIcon

    var body: some View {
        switch icon {
        case let .emoji(emoji, backgroundColor):
            ZStack {
                Circle()
                    .fill(backgroundColor)
                Text(emoji)
                    .font(.system(size: Layout.emojiFontSize))
            }
            .frame(width: Layout.containerSize, height: Layout.containerSize)
        case let .image(configuration):
            ZStack {
                Circle()
                    .fill(configuration.backgroundColor)
                configuration.image
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
                    .foregroundStyle(configuration.tintColor)
                    .frame(
                        width: configuration.imageSize.width,
                        height: configuration.imageSize.height
                    )
            }
            .frame(width: Layout.containerSize, height: Layout.containerSize)
        case let .url(url):
            AssetAvatarView(
                imageSource: .url(url),
                size: .small,
                shape: .rectangle(cornerRadius: Layout.urlIconCornerRadius)
            )
        }
    }

    private enum Layout {
        static let containerSize: CGFloat = 44
        static let emojiFontSize: CGFloat = 24
        static let urlIconCornerRadius: CGFloat = 12
    }
}

private struct SettingsListItemToggleView: View {
    let toggle: SettingsListItemToggleAccessory

    var body: some View {
        ZStack(alignment: toggle.isOn ? .trailing : .leading) {
            Capsule()
                .fill(trackColor)
                .frame(width: Layout.trackWidth, height: Layout.trackHeight)

            Circle()
                .fill(.constantWhite)
                .frame(width: Layout.thumbSize, height: Layout.thumbSize)
                .padding(Layout.thumbInset)
                .shadow(
                    color: Color.black.opacity(0.12),
                    radius: 1,
                    x: 0,
                    y: 1
                )
        }
        .animation(.easeInOut(duration: 0.2), value: toggle.isOn)
        .opacity(toggle.isEnabled ? 1 : 0.48)
        .padding(.trailing, Layout.trailingInset)
    }

    private var trackColor: TKColor {
        toggle.isOn
            ? .accentBlue
            : .buttonTertiaryBackground
    }
}

private extension SettingsListItemToggleView {
    enum Layout {
        static let trackWidth: CGFloat = 51
        static let trackHeight: CGFloat = 31
        static let thumbSize: CGFloat = 27
        static let thumbInset: CGFloat = 2
        static let trailingInset: CGFloat = 16
    }
}
