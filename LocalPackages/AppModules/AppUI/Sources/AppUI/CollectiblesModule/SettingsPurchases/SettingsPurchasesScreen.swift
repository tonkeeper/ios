import SwiftUI
import TKUIKit
import UIKit

public struct SettingsPurchasesScreen: View {
    private let state: SettingsPurchasesScreenState
    private let onBack: () -> Void
    private let onCopy: (String) -> Void

    public init(
        state: SettingsPurchasesScreenState,
        onBack: @escaping () -> Void,
        onCopy: @escaping (String) -> Void
    ) {
        self.state = state
        self.onBack = onBack
        self.onCopy = onCopy
    }

    public var body: some View {
        VStack(spacing: 0) {
            header

            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    ForEach(state.sections) { section in
                        SettingsPurchasesSectionView(section: section)
                    }
                }
                .padding(.bottom, Layout.contentBottomPadding)
            }
            .tkImmediateButtonPresses()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(.backgroundPage)
        .tkBottomSheet(
            item: Binding(
                get: { state.details },
                set: { presentation in
                    guard presentation == nil else { return }
                    state.onDismissDetails()
                }
            ),
            header: { presentation, _ in
                TKBottomSheetHeaderConfiguration(
                    title: .title(title: presentation.state.title),
                    contentInsets: Layout.detailsHeaderContentInsets
                )
            },
            content: { presentation in
                PurchasesManagementDetailsView(
                    state: presentation.state,
                    onCopy: onCopy
                )
            }
        )
    }
}

private extension SettingsPurchasesScreen {
    var header: some View {
        DefaultModalCardHeader(
            config: .push(
                title: state.title,
                backAccessibilityIdentifier: "header_back",
                onBack: onBack
            )
        )
        .fixedSize(horizontal: false, vertical: true)
    }

    enum Layout {
        static let contentBottomPadding: CGFloat = 16
        static let detailsHeaderContentInsets = UIEdgeInsets(
            top: 16,
            left: 16,
            bottom: 8,
            right: 16
        )
    }
}

private struct SettingsPurchasesSectionView: View {
    let section: SettingsPurchasesScreenState.Section

    var body: some View {
        VStack(spacing: 0) {
            ListTitleView(config: .text(section.title))
                .padding(.horizontal, Layout.horizontalPadding)

            LazyVStack(spacing: 0) {
                ForEach(Array(section.items.enumerated()), id: \.element.id) { index, item in
                    SettingsPurchasesItemCell(
                        item: item,
                        showsDivider: index < section.items.count - 1
                    )
                }
            }
            // Padding is applied here rather than by the group so that a lone tappable cell, which
            // the group hands its horizontal padding to, keeps the leading control overlay aligned.
            .asCellsGroup(config: CellsGroupModifier.Config(horizontalPadding: 0))
            .padding(.horizontal, Layout.horizontalPadding)

            if let showAllButton = section.showAllButton {
                ButtonView(
                    config: ButtonView.Config(
                        title: showAllButton.title,
                        size: .small,
                        appearance: .secondary,
                        action: showAllButton.action
                    )
                )
                .padding(.top, Layout.showAllButtonTopPadding)
            }
        }
        .padding(.bottom, section.showAllButton == nil ? Layout.sectionBottomPadding : 0)
    }
}

private extension SettingsPurchasesSectionView {
    enum Layout {
        static let horizontalPadding: CGFloat = 16
        static let showAllButtonTopPadding: CGFloat = 16
        static let sectionBottomPadding: CGFloat = 16
    }
}

private struct SettingsPurchasesItemCell: View {
    let item: SettingsPurchasesScreenState.Item
    let showsDivider: Bool

    var body: some View {
        Cell(
            config: Cell.Config(
                style: .grouped,
                showsDivider: showsDivider,
                action: item.action
            ),
            leading: {
                HStack(spacing: 0) {
                    if item.control != nil {
                        Color.clear
                            .frame(width: Layout.controlWidth)
                            .padding(.leading, Layout.controlLeadingPadding)
                    }

                    CellAssetLeading {
                        imageView
                    }
                }
            },
            center: {
                CellCenter {
                    CellCenterPrimaryRow(
                        config: .content(
                            CellCenterPrimaryRow.Content(title: item.title)
                        )
                    )
                } secondaryRow: {
                    CellCenterSecondaryRow(
                        config: .content(
                            CellCenterSecondaryRow.Content(
                                value: CellCenterSecondaryRow.ValueConfig(title: item.subtitle)
                            )
                        )
                    )
                }
            },
            trailing: {
                if item.showsChevron {
                    CellTrailingAccessory(
                        config: CellTrailingAccessory.Config(
                            color: .iconTertiary,
                            icon: SwiftUI.Image.TKUIKit.Icons.Size16.chevronRight,
                            iconSize: Layout.chevronSize
                        )
                    )
                }
            }
        )
        .overlay(alignment: .leading) {
            if let control = item.control {
                SettingsPurchasesItemControlView(control: control)
                    .padding(.leading, Layout.controlLeadingPadding)
            }
        }
    }
}

private extension SettingsPurchasesItemCell {
    @ViewBuilder
    var imageView: some View {
        switch item.image {
        case let .url(url):
            AssetAvatarView(
                imageSource: .url(url),
                size: .small,
                shape: .rectangle(cornerRadius: Layout.imageCornerRadius)
            )
        case let .icon(image):
            SwiftUI.Image(uiImage: image)
                .resizable()
                .scaledToFit()
        }
    }

    enum Layout {
        static let controlWidth: CGFloat = 28
        static let controlLeadingPadding: CGFloat = 16
        static let imageCornerRadius: CGFloat = 8
        static let chevronSize: CGFloat = 16
    }
}

private struct SettingsPurchasesItemControlView: View {
    let control: SettingsPurchasesScreenState.Item.Control

    var body: some View {
        Button(action: control.action) {
            ZStack {
                Circle()
                    .fill(.backgroundContentTint)

                SwiftUI.Image(uiImage: icon)
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
                    .foregroundStyle(.iconPrimary)
                    .frame(width: Layout.iconSize, height: Layout.iconSize)
            }
            .frame(width: Layout.circleSize, height: Layout.circleSize)
            .frame(width: Layout.width)
            .frame(maxHeight: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(TKTapAnimationButtonStyle(haptic: .light))
        .accessibilityIdentifier(accessibilityIdentifier)
    }
}

private extension SettingsPurchasesItemControlView {
    var icon: UIImage {
        switch control.kind {
        case .hide:
            .TKUIKit.Icons.Size16.minus
        case .show:
            .TKUIKit.Icons.Size16.plus
        }
    }

    var accessibilityIdentifier: String {
        switch control.kind {
        case .hide:
            "filter_minus"
        case .show:
            "filter_plus"
        }
    }

    enum Layout {
        static let width: CGFloat = 28
        static let circleSize: CGFloat = 24
        static let iconSize: CGFloat = 16
    }
}
