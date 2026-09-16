import SwiftUI
import TKUIKit

struct PurchasesManagementDetailsView: View {
    private let state: PurchasesManagementDetailsViewState
    private let onCopy: (String) -> Void

    init(
        state: PurchasesManagementDetailsViewState,
        onCopy: @escaping (String) -> Void
    ) {
        self.state = state
        self.onCopy = onCopy
    }

    var body: some View {
        VStack(spacing: 0) {
            itemsList
            button
        }
        .padding(.top, Layout.topPadding)
        .frame(maxWidth: .infinity, alignment: .top)
        .ignoresSafeArea(.container, edges: .top)
        .background(.backgroundPage)
    }
}

private extension PurchasesManagementDetailsView {
    var itemsList: some View {
        VStack(spacing: 0) {
            ForEach(Array(state.items.enumerated()), id: \.element.id) { index, item in
                PurchasesManagementDetailsItemCell(
                    item: item,
                    showsDivider: index < state.items.count - 1,
                    onCopy: onCopy
                )
            }
        }
        .asCellsGroup()
    }

    var button: some View {
        ButtonView(
            config: ButtonView.Config(
                title: state.button.title,
                size: .large,
                layoutMode: .fill,
                appearance: .secondary,
                action: state.button.action
            )
        )
        .padding(.horizontal, Layout.buttonHorizontalPadding)
        .padding(.top, Layout.buttonTopPadding)
        .padding(.bottom, Layout.buttonBottomPadding)
    }

    enum Layout {
        static let topPadding: CGFloat = 8
        static let buttonHorizontalPadding: CGFloat = 16
        static let buttonTopPadding: CGFloat = 16
        static let buttonBottomPadding: CGFloat = 3
    }
}

private struct PurchasesManagementDetailsItemCell: View {
    let item: PurchasesManagementDetailsViewState.Item
    let showsDivider: Bool
    let onCopy: (String) -> Void

    var body: some View {
        Cell(
            config: Cell.Config(
                style: .grouped,
                showsDivider: showsDivider,
                action: copyAction
            ),
            center: {
                CellCenter {
                    CellCenterPrimaryRow(
                        config: .content(
                            CellCenterPrimaryRow.Content(
                                title: CellCenterPrimaryRow.TitleConfig(
                                    text: item.title,
                                    color: .textSecondary,
                                    style: .body1
                                )
                            )
                        )
                    )
                } secondaryRow: {
                    CellCenterSecondaryRow(
                        config: .content(
                            CellCenterSecondaryRow.Content(
                                value: CellCenterSecondaryRow.ValueConfig(
                                    title: item.value,
                                    textStyle: .label1,
                                    textColor: .textPrimary,
                                    truncationMode: .middle
                                )
                            )
                        )
                    )
                }
            },
            trailing: {
                accessoryView
            }
        )
    }
}

private extension PurchasesManagementDetailsItemCell {
    var copyAction: (() -> Void)? {
        guard let copyValue = item.copyValue else {
            return nil
        }
        return {
            onCopy(copyValue)
        }
    }

    @ViewBuilder
    var accessoryView: some View {
        switch item.accessory {
        case .none:
            EmptyView()
        case .copy:
            CellTrailingAccessory(
                config: CellTrailingAccessory.Config(
                    color: .iconSecondary,
                    icon: SwiftUI.Image.TKUIKit.Icons.Size16.copy,
                    iconSize: Layout.copyIconSize
                )
            )
        case let .image(url):
            AssetAvatarView(
                imageSource: .url(url),
                configuration: Layout.imageConfiguration,
                shape: .rectangle(cornerRadius: Layout.imageCornerRadius)
            )
            .padding(.trailing, Layout.imageTrailingPadding)
        }
    }

    enum Layout {
        static let copyIconSize: CGFloat = 16
        static let imageCornerRadius: CGFloat = 8
        static let imageTrailingPadding: CGFloat = 16
        static let imageConfiguration = AssetAvatarView.Configuration(
            imageSize: 40,
            chainIconSize: 0,
            chainIconPadding: 0,
            chainIconOffsetX: 0,
            chainIconOffsetY: 0
        )
    }
}
