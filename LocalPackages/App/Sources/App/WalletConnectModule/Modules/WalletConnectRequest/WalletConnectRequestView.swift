import SwiftUI
import TKLocalize
import TKUIKit
import UIKit

struct WalletConnectRequestScreen: View {
    @ObservedObject var viewModel: WalletConnectRequestViewModel

    var body: some View {
        ZStack(alignment: .bottom) {
            VStack(spacing: 0) {
                header
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 0) {
                        hero
                        detailsList
                    }
                    .padding(.bottom, Layout.scrollBottomPadding)
                }
                .tkImmediateButtonPresses()
            }

            actionBar
        }
        .background(.backgroundPage)
    }
}

private extension WalletConnectRequestScreen {
    var header: some View {
        DefaultModalCardHeader(
            config: DefaultModalCardHeader.Config(
                title: .empty,
                rightIcon: viewModel.canDismiss
                    ? .close(
                        onTap: { _ in
                            viewModel.reject()
                        }
                    )
                    : nil,
                height: .atLeast(Layout.headerHeight)
            )
        )
        .fixedSize(horizontal: false, vertical: true)
    }

    var hero: some View {
        VStack(spacing: 0) {
            AssetAvatarView(
                imageSource: .url(
                    viewModel.content.dappIconURL,
                    chainIcon: viewModel.content.chainIcon
                ),
                size: .extraLarge
            )
            .padding(.bottom, Layout.avatarBottomPadding)

            VStack(spacing: Layout.heroTextSpacing) {
                Text(viewModel.content.description)
                    .textStyle(.body1)
                    .foregroundStyle(.textSecondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(1)

                Text(viewModel.content.headline)
                    .textStyle(.h3)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, Layout.heroHorizontalPadding)
            .padding(.bottom, Layout.heroBottomPadding)
        }
    }

    var detailsList: some View {
        WalletConnectRequestDetailsList(
            content: viewModel.content,
            isAdvancedDetailsExpanded: viewModel.isAdvancedDetailsExpanded,
            openDAppHost: viewModel.openDAppHost,
            toggleAdvancedDetails: viewModel.toggleAdvancedDetails
        )
    }

    var actionBar: some View {
        VStack(spacing: 0) {
            ZStack {
                WalletConnectRequestConfirmSliderRepresentable(
                    title: sliderTitle,
                    isEnabled: viewModel.actionBarState == .idle && viewModel.canApprove,
                    onConfirm: viewModel.approve
                )
                .opacity(viewModel.actionBarState == .idle && viewModel.canApprove ? 1 : 0)
                .disabled(viewModel.actionBarState != .idle || !viewModel.canApprove)

                actionBarOverlay
            }
            .frame(height: Layout.actionBarHeight)
            .padding(.horizontal, Layout.actionHorizontalPadding)
        }
        .background(.backgroundPage.opacity(0.96), ignoresSafeAreaEdges: .bottom)
    }

    @ViewBuilder
    var actionBarOverlay: some View {
        switch viewModel.actionBarState {
        case .idle:
            EmptyView()
        case .loading:
            CircularLoader(
                mode: .indeterminate,
                preset: .medium
            )
        case .success:
            WalletConnectRequestActionResultView(state: .success)
        case .failure:
            WalletConnectRequestActionResultView(state: .failure)
        }
    }

    var sliderTitle: NSAttributedString {
        let result = NSMutableAttributedString()
        result.append(
            "\(TKLocales.Actions.Confirm.title)\n".withTextStyle(
                .label2,
                color: .Text.secondary,
                alignment: .center
            )
        )
        result.append(
            TKLocales.Actions.Confirm.subtitle.withTextStyle(
                .body3,
                color: .Text.tertiary,
                alignment: .center
            )
        )
        return result
    }

    enum Layout {
        static let headerHeight: CGFloat = 64
        static let avatarBottomPadding: CGFloat = 21
        static let heroTextSpacing: CGFloat = 3
        static let heroHorizontalPadding: CGFloat = 32
        static let heroBottomPadding: CGFloat = 32
        static let scrollBottomPadding: CGFloat = 104
        static let actionBarHeight: CGFloat = 88
        static let actionHorizontalPadding: CGFloat = 16
    }
}

private struct WalletConnectRequestDetailsList: View {
    let content: WalletConnectRequestContent
    let isAdvancedDetailsExpanded: Bool
    let openDAppHost: () -> Void
    let toggleAdvancedDetails: () -> Void

    @State private var expandedDetailIDs: Set<String>

    init(
        content: WalletConnectRequestContent,
        isAdvancedDetailsExpanded: Bool,
        openDAppHost: @escaping () -> Void,
        toggleAdvancedDetails: @escaping () -> Void
    ) {
        self.content = content
        self.isAdvancedDetailsExpanded = isAdvancedDetailsExpanded
        self.openDAppHost = openDAppHost
        self.toggleAdvancedDetails = toggleAdvancedDetails
        self._expandedDetailIDs = State(
            initialValue: Self.defaultExpandedDetailIDs(in: content.advancedDetails)
        )
    }

    var body: some View {
        VStack(spacing: 0) {
            ForEach(content.rows.indices, id: \.self) { index in
                WalletConnectRequestInfoCell(
                    row: content.rows[index],
                    showsDivider: showsDivider(forRowAt: index),
                    action: action(for: content.rows[index])
                )
            }

            if !content.advancedDetails.isEmpty {
                WalletConnectRequestAdvancedCell(
                    isExpanded: isAdvancedDetailsExpanded,
                    showsDivider: false,
                    action: toggleAdvancedDetails
                )

                if isAdvancedDetailsExpanded {
                    let rows = visibleAdvancedDetailRows
                    ForEach(rows.indices, id: \.self) { index in
                        WalletConnectRequestDetailCell(
                            row: rows[index],
                            action: action(for: rows[index])
                        )
                    }
                }

                Color.clear
                    .frame(maxWidth: .infinity)
                    .frame(height: 8)
            }
        }
        .asCellsGroup()
    }

    private func showsDivider(forRowAt index: Int) -> Bool {
        index < content.rows.count - 1 || !content.advancedDetails.isEmpty
    }

    private func action(for row: WalletConnectRequestInfoRow) -> (() -> Void)? {
        guard row.id == .app, content.dappURL != nil else {
            return nil
        }
        return openDAppHost
    }

    private var visibleAdvancedDetailRows: [WalletConnectRequestDetailRow] {
        content.advancedDetails.flatMap {
            visibleRows(for: $0, depth: 0)
        }
    }

    private func visibleRows(
        for item: WalletConnectRequestDetailItem,
        depth: Int
    ) -> [WalletConnectRequestDetailRow] {
        switch item.value {
        case let .primitive(value):
            return [
                WalletConnectRequestDetailRow(
                    id: item.id,
                    title: item.title,
                    value: value,
                    depth: depth,
                    isExpandable: false,
                    isExpanded: false
                ),
            ]

        case let .collection(children):
            let isExpanded = expandedDetailIDs.contains(item.id)
            var rows = [
                WalletConnectRequestDetailRow(
                    id: item.id,
                    title: item.title,
                    value: nil,
                    depth: depth,
                    isExpandable: true,
                    isExpanded: isExpanded
                ),
            ]

            guard isExpanded else { return rows }

            if depth >= Layout.maximumNestedDepth {
                rows.append(
                    contentsOf: flattenedRows(
                        for: children,
                        depth: depth
                    )
                )
            } else {
                rows.append(
                    contentsOf: children.flatMap {
                        visibleRows(for: $0, depth: depth + 1)
                    }
                )
            }

            return rows
        }
    }

    private func flattenedRows(
        for items: [WalletConnectRequestDetailItem],
        parentPath: String? = nil,
        depth: Int
    ) -> [WalletConnectRequestDetailRow] {
        items.flatMap { item in
            let title = parentPath.map { "\($0).\(item.title)" } ?? item.title

            switch item.value {
            case let .primitive(value):
                return [
                    WalletConnectRequestDetailRow(
                        id: "\(item.id).flat",
                        title: title,
                        value: value,
                        depth: depth,
                        isExpandable: false,
                        isExpanded: false
                    ),
                ]

            case let .collection(children):
                return flattenedRows(
                    for: children,
                    parentPath: title,
                    depth: depth
                )
            }
        }
    }

    private func action(for row: WalletConnectRequestDetailRow) -> (() -> Void)? {
        guard row.isExpandable else { return nil }
        return {
            if expandedDetailIDs.contains(row.id) {
                expandedDetailIDs.remove(row.id)
            } else {
                expandedDetailIDs.insert(row.id)
            }
        }
    }

    private static func defaultExpandedDetailIDs(
        in items: [WalletConnectRequestDetailItem]
    ) -> Set<String> {
        items.reduce(into: Set<String>()) { result, item in
            if item.isDefaultExpanded {
                result.insert(item.id)
            }

            if case let .collection(children) = item.value {
                result.formUnion(defaultExpandedDetailIDs(in: children))
            }
        }
    }

    enum Layout {
        static let maximumNestedDepth = 2
    }
}

private struct WalletConnectRequestInfoCell: View {
    let row: WalletConnectRequestInfoRow
    let showsDivider: Bool
    let action: (() -> Void)?

    var body: some View {
        Cell(
            config: Cell.Config(
                style: .regular,
                showsDivider: showsDivider,
                action: action
            ),
            center: {
                VStack(alignment: .leading, spacing: Layout.subtitleSpacing) {
                    HStack(alignment: .center, spacing: Layout.rowSpacing) {
                        Text(row.title)
                            .textStyle(.body1)
                            .foregroundStyle(.textSecondary)
                            .lineLimit(1)

                        Spacer(minLength: 0)

                        HStack(spacing: Layout.valueSpacing) {
                            if let valueIcon = row.valueIcon {
                                SwiftUI.Image(uiImage: valueIcon)
                                    .renderingMode(.template)
                                    .resizable()
                                    .scaledToFit()
                                    .foregroundStyle(.iconPrimary)
                                    .frame(
                                        width: Layout.valueIconSize,
                                        height: Layout.valueIconSize
                                    )
                            }

                            Text(row.value)
                                .textStyle(.label1)
                                .multilineTextAlignment(.trailing)
                                .lineLimit(1)

                            if let trailingIcon = row.trailingIcon {
                                SwiftUI.Image(uiImage: trailingIcon)
                                    .renderingMode(.template)
                                    .resizable()
                                    .scaledToFit()
                                    .foregroundStyle(row.trailingIconColor)
                                    .frame(
                                        width: Layout.trailingIconSize,
                                        height: Layout.trailingIconSize
                                    )
                            }
                        }
                    }

                    if let subtitle = row.subtitle {
                        Text(subtitle)
                            .textStyle(.body2)
                            .foregroundStyle(.textSecondary)
                            .multilineTextAlignment(.trailing)
                            .lineLimit(1)
                            .truncationMode(.middle)
                            .frame(maxWidth: .infinity, alignment: .trailing)
                    }
                }
                .padding(.horizontal, Layout.horizontalPadding)
                .padding(.vertical, row.subtitle == nil ? Layout.singleLineVerticalPadding : Layout.multilineVerticalPadding)
            }
        )
    }

    enum Layout {
        static let horizontalPadding: CGFloat = 16
        static let singleLineVerticalPadding: CGFloat = 16
        static let multilineVerticalPadding: CGFloat = 17
        static let rowSpacing: CGFloat = 8
        static let valueSpacing: CGFloat = 6
        static let subtitleSpacing: CGFloat = -3
        static let valueIconSize: CGFloat = 20
        static let trailingIconSize: CGFloat = 16
    }
}

private struct WalletConnectRequestAdvancedCell: View {
    let isExpanded: Bool
    let showsDivider: Bool
    let action: () -> Void

    var body: some View {
        Cell(
            config: Cell.Config(
                style: .regular,
                showsDivider: showsDivider,
                action: action
            ),
            center: {
                CellCenter(
                    primaryRow: {
                        CellCenterPrimaryRow(
                            config: .content(
                                CellCenterPrimaryRow.Content(
                                    title: CellCenterPrimaryRow.TitleConfig(
                                        text: TKLocales.WalletConnect.Request.advancedDetails,
                                        color: .textSecondary,
                                        style: .body1
                                    )
                                )
                            )
                        )
                    },
                    contentInsets: {
                        $0.bottom -= 9
                    }
                )
            },
            trailing: {
                SwiftUI.Image.TKUIKit.Icons.Size16.chevronDown
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
                    .foregroundStyle(.iconTertiary)
                    .frame(width: Layout.iconSize, height: Layout.iconSize)
                    .rotation3DEffect(
                        .degrees(isExpanded ? 180 : 0),
                        axis: (x: 1, y: 0, z: 0)
                    )
                    .padding(.trailing, Layout.trailingPadding)
            }
        )
    }

    enum Layout {
        static let trailingPadding: CGFloat = 16
        static let iconSize: CGFloat = 16
    }
}

private struct WalletConnectRequestDetailRow: Identifiable {
    let id: String
    let title: String
    let value: String?
    let depth: Int
    let isExpandable: Bool
    let isExpanded: Bool
}

private struct WalletConnectRequestDetailCell: View {
    let row: WalletConnectRequestDetailRow
    let action: (() -> Void)?
    @Environment(\.tkPalette) private var palette

    var body: some View {
        Cell(
            config: Cell.Config(
                style: .regular,
                showsDivider: false,
                action: action
            ),
            center: {
                Group {
                    if let value = row.value {
                        Text(detailText(title: row.title, value: value))
                            .textStyle(.body2)
                            .lineLimit(Layout.valueLineLimit)
                            .truncationMode(.middle)
                            .fixedSize(horizontal: false, vertical: true)
                    } else {
                        Text(row.title)
                            .textStyle(.body2)
                            .foregroundStyle(.textSecondary)
                            .lineLimit(1)
                            .truncationMode(.tail)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.leading, leadingPadding)
                .padding(.trailing, row.isExpandable ? 0 : Layout.trailingPadding)
                .padding(.top, Layout.topPadding)
                .frame(minHeight: Layout.minimumHeight, alignment: .top)
            },
            trailing: {
                if row.isExpandable {
                    SwiftUI.Image.TKUIKit.Icons.Size16.chevronDown
                        .renderingMode(.template)
                        .resizable()
                        .scaledToFit()
                        .foregroundStyle(.iconTertiary)
                        .frame(width: Layout.iconSize, height: Layout.iconSize)
                        .rotation3DEffect(
                            .degrees(row.isExpanded ? 180 : 0),
                            axis: (x: 1, y: 0, z: 0)
                        )
                        .padding(.trailing, Layout.trailingPadding)
                }
            }
        )
    }

    private var leadingPadding: CGFloat {
        Layout.leadingPaddings[
            min(row.depth, Layout.leadingPaddings.count - 1)
        ]
    }

    private func detailText(title: String, value: String) -> AttributedString {
        var title = AttributedString("\(title): ")
        title.foregroundColor = palette.text.secondary

        var value = AttributedString(value)
        value.foregroundColor = palette.text.primary

        return title + value
    }

    enum Layout {
        static let leadingPaddings: [CGFloat] = [16, 24, 36]
        static let trailingPadding: CGFloat = 16
        static let topPadding: CGFloat = 3
        static let minimumHeight: CGFloat = 28
        static let iconSize: CGFloat = 16
        static let valueLineLimit = 4
    }
}

private struct WalletConnectRequestConfirmSliderRepresentable: UIViewRepresentable {
    let title: NSAttributedString
    let isEnabled: Bool
    let onConfirm: () -> Void

    func makeUIView(context: Context) -> TKSlider {
        let slider = TKSlider()
        slider.appearance = .standart
        slider.title = title
        slider.isEnable = isEnabled
        slider.didConfirm = onConfirm
        slider.swipeHandleAccessibilityIdentifier = "confirm_swipe"
        return slider
    }

    func updateUIView(_ uiView: TKSlider, context: Context) {
        uiView.title = title
        uiView.isEnable = isEnabled
        uiView.didConfirm = onConfirm
    }
}

private struct WalletConnectRequestActionResultView: View {
    enum State {
        case success
        case failure

        var title: String {
            switch self {
            case .success:
                TKLocales.Result.success
            case .failure:
                TKLocales.Result.failure
            }
        }

        var tintColor: TKColor {
            switch self {
            case .success:
                .accentGreen
            case .failure:
                .accentRed
            }
        }

        var icon: UIImage {
            switch self {
            case .success:
                .TKUIKit.Icons.Size32.checkmarkCircle
            case .failure:
                .TKUIKit.Icons.Size32.exclamationmarkCircle
            }
        }
    }

    let state: State

    var body: some View {
        VStack(spacing: Layout.spacing) {
            SwiftUI.Image(uiImage: state.icon)
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .frame(width: Layout.iconSize, height: Layout.iconSize)

            Text(state.title)
                .textStyle(.label2)
                .lineLimit(1)
        }
        .foregroundStyle(state.tintColor)
        .frame(maxWidth: .infinity, minHeight: Layout.height)
    }

    enum Layout {
        static let iconSize: CGFloat = 32
        static let spacing: CGFloat = 4
        static let height: CGFloat = 56
    }
}
