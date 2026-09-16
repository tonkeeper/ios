import SwiftUI
import TKUIKit
import UIKit

public struct NFTDetailsScreen: View {
    private let state: NFTDetailsScreenState
    private let onClose: () -> Void
    private let onCopy: (String) -> Void

    public init(
        state: NFTDetailsScreenState,
        onClose: @escaping () -> Void,
        onCopy: @escaping (String) -> Void
    ) {
        self.state = state
        self.onClose = onClose
        self.onCopy = onCopy
    }

    public var body: some View {
        VStack(spacing: 0) {
            NFTDetailsHeaderView(
                header: state.header,
                onClose: onClose
            )

            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    if let spamActions = state.spamActions {
                        NFTDetailsSpamActionsView(actions: spamActions)
                    }

                    NFTDetailsInformationView(information: state.information)

                    if !state.buttons.isEmpty {
                        NFTDetailsButtonsView(buttons: state.buttons)
                    }

                    if let properties = state.properties {
                        NFTDetailsPropertiesView(properties: properties)
                    }

                    NFTDetailsListView(
                        details: state.details,
                        onCopy: onCopy
                    )
                }
            }
            .tkImmediateButtonPresses()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(.backgroundPage)
    }
}

private struct NFTDetailsHeaderView: View {
    let header: NFTDetailsScreenState.Header
    let onClose: () -> Void

    var body: some View {
        DefaultModalCardHeader(config: config)
            .fixedSize(horizontal: false, vertical: true)
    }

    private var config: DefaultModalCardHeader.Config {
        DefaultModalCardHeader.Config(
            leftIcon: leftIcon,
            title: DefaultModalCardHeader.Title(text: header.title),
            subtitle: header.caption.map { caption in
                DefaultModalCardHeader.Subtitle(
                    text: caption.title,
                    color: caption.color,
                    icon: DefaultModalCardHeader.SubtitleIcon(
                        image: .TKUIKit.Icons.Size12.informationCircle,
                        size: Layout.captionIconSize,
                        topPadding: Layout.captionIconTopPadding
                    ),
                    onTap: caption.action
                )
            },
            rightIcon: header.menuItems.isEmpty ? nil : menuIcon
        )
    }

    private var leftIcon: DefaultModalCardHeader.Icon {
        switch header.leftButton {
        case .back:
            DefaultModalCardHeader.Icon.back { _ in onClose() }
        case .swipeDown:
            DefaultModalCardHeader.Icon(
                image: .TKUIKit.Icons.Size16.chevronDown,
                size: Layout.headerIconSize,
                padding: Layout.headerIconPadding,
                onTap: { _ in onClose() }
            )
        }
    }

    private var menuIcon: DefaultModalCardHeader.Icon {
        DefaultModalCardHeader.Icon(
            image: .TKUIKit.Icons.Size16.ellipses,
            size: Layout.headerIconSize,
            padding: Layout.headerIconPadding,
            onTap: { sourceView in
                guard let sourceView else { return }
                TKPopupMenuController.show(
                    sourceView: sourceView,
                    position: .bottomRight(inset: Layout.menuInset),
                    minimumWidth: 0,
                    items: header.menuItems,
                    isSelectable: false,
                    selectedIndex: nil
                )
            }
        )
    }

    private enum Layout {
        static let headerIconSize: CGFloat = 16
        static let headerIconPadding: CGFloat = 8
        static let captionIconSize: CGFloat = 12
        static let captionIconTopPadding: CGFloat = 4
        static let menuInset: CGFloat = 8
    }
}

private struct NFTDetailsSpamActionsView: View {
    let actions: NFTDetailsScreenState.SpamActions

    var body: some View {
        HStack(spacing: Layout.spacing) {
            ButtonView(
                config: ButtonView.Config(
                    title: actions.reportSpamTitle,
                    size: .medium,
                    layoutMode: .fill,
                    appearance: .primaryAttention,
                    action: actions.onReportSpam
                )
            )

            ButtonView(
                config: ButtonView.Config(
                    title: actions.notSpamTitle,
                    size: .medium,
                    layoutMode: .fill,
                    appearance: .secondary,
                    action: actions.onNotSpam
                )
            )
        }
        .padding(.top, Layout.topPadding)
        .padding(.horizontal, Layout.horizontalPadding)
        .padding(.bottom, Layout.bottomPadding)
    }

    private enum Layout {
        static let spacing: CGFloat = 8
        static let topPadding: CGFloat = 8
        static let bottomPadding: CGFloat = 16
        static let horizontalPadding: CGFloat = 16
    }
}

private struct NFTDetailsInformationView: View {
    let information: NFTDetailsScreenState.Information

    var body: some View {
        VStack(spacing: 0) {
            NFTDetailsHeroView(
                imageSource: information.imageSource,
                lottieURL: information.lottieURL,
                isBlurred: information.isBlurred,
                isOnSale: information.isOnSale
            )

            itemInformation

            if let collectionSection = information.collectionSection {
                TKColor.separatorCommon
                    .frame(height: TKUIKit.Constants.separatorWidth)

                collectionInformation(collectionSection)
            }
        }
        .background(.backgroundContent)
        .clipShape(
            RoundedRectangle(cornerRadius: Layout.cornerRadius, style: .continuous)
        )
        .padding(.horizontal, Layout.horizontalPadding)
        .padding(.bottom, Layout.bottomPadding)
    }

    private var itemInformation: some View {
        VStack(alignment: .leading, spacing: Layout.itemSpacing) {
            Text(information.name)
                .textStyle(.h2)
                .foregroundStyle(.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 1)

            HStack(spacing: Layout.collectionSpacing) {
                Text(information.collectionName)
                    .textStyle(.body2)
                    .foregroundStyle(.textSecondary)
                    .lineLimit(1)

                if information.isCollectionVerified {
                    SwiftUI.Image.TKUIKit.Icons.Size16.verificationBlueTint
                        .resizable()
                        .scaledToFit()
                        .frame(
                            width: Layout.verificationIconSize,
                            height: Layout.verificationIconSize
                        )
                }
            }
            .padding(.top, -1)

            if let description = information.description, !description.isEmpty {
                expandableText(description)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Layout.contentInsets)
    }

    private func collectionInformation(
        _ section: NFTDetailsScreenState.Information.CollectionSection
    ) -> some View {
        VStack(alignment: .leading, spacing: Layout.collectionSectionSpacing) {
            Text(section.title)
                .textStyle(.label1)
                .foregroundStyle(.textPrimary)
                .lineLimit(1)
                .padding(.top, 1)

            if let description = section.description, !description.isEmpty {
                expandableText(description)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Layout.contentInsets)
    }

    private func expandableText(_ text: String) -> some View {
        TKExpandableTextView(
            text: text,
            collapsedLineLimit: Layout.descriptionLineLimit,
            moreTitle: information.moreTitle,
            style: .inline()
        )
    }

    private enum Layout {
        static let cornerRadius: CGFloat = 16
        static let horizontalPadding: CGFloat = 16
        static let bottomPadding: CGFloat = 16
        static let itemSpacing: CGFloat = 4
        static let collectionSpacing: CGFloat = 4
        static let collectionSectionSpacing: CGFloat = 7
        static let verificationIconSize: CGFloat = 16
        static let descriptionLineLimit = 2
        static let contentInsets = EdgeInsets(
            top: 14,
            leading: 16,
            bottom: 12,
            trailing: 16
        )
    }
}

private struct NFTDetailsButtonsView: View {
    let buttons: [NFTDetailsScreenState.Button]

    var body: some View {
        VStack(spacing: Layout.spacing) {
            ForEach(buttons) { button in
                VStack(spacing: Layout.descriptionSpacing) {
                    ButtonView(
                        config: ButtonView.Config(
                            title: button.title,
                            size: .large,
                            layoutMode: .fill,
                            appearance: button.appearance,
                            icon: button.icon,
                            showsLoader: button.showsLoader,
                            action: button.action
                        )
                    )
                    .disabled(!button.isEnabled)

                    if let description = button.description {
                        Text(description)
                            .textStyle(.body2)
                            .foregroundStyle(.textSecondary)
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)
                            .frame(maxWidth: .infinity)
                            .padding(.bottom, -2)
                    }
                }
            }
        }
        .padding(.horizontal, Layout.horizontalPadding)
        .padding(.bottom, Layout.bottomPadding)
    }

    private enum Layout {
        static let spacing: CGFloat = 16
        static let descriptionSpacing: CGFloat = 11
        static let horizontalPadding: CGFloat = 16
        static let bottomPadding: CGFloat = 16
    }
}

struct NFTDetailsPropertiesView: View {
    let properties: NFTDetailsScreenState.Properties

    var body: some View {
        VStack(spacing: 0) {
            ListTitleView(config: .text(properties.title))
                .padding(.horizontal, Layout.horizontalPadding)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .top, spacing: Layout.spacing) {
                    ForEach(properties.properties) { property in
                        propertyView(property)
                    }
                }
                .padding(.horizontal, Layout.horizontalPadding)
            }
        }
        .padding(.bottom, Layout.bottomPadding)
    }

    private func propertyView(
        _ property: NFTDetailsScreenState.Properties.Property
    ) -> some View {
        VStack(alignment: .leading, spacing: -5) {
            Text(property.title)
                .textStyle(.body1)
                .foregroundStyle(.textSecondary)
                .lineLimit(1)

            Text(property.value)
                .textStyle(.body1)
                .foregroundStyle(.textPrimary)
                .lineLimit(1)
        }
        .padding(Layout.propertyInsets)
        .background(
            RoundedRectangle(cornerRadius: Layout.cornerRadius, style: .continuous)
                .fill(.backgroundContent)
        )
    }

    private enum Layout {
        static let horizontalPadding: CGFloat = 16
        static let spacing: CGFloat = 12
        static let bottomPadding: CGFloat = 20
        static let cornerRadius: CGFloat = 16
        static let propertyInsets = EdgeInsets(
            top: 8,
            leading: 16,
            bottom: 10,
            trailing: 16
        )
    }
}

struct NFTDetailsListView: View {
    let details: NFTDetailsScreenState.Details
    let onCopy: (String) -> Void

    var body: some View {
        VStack(spacing: 0) {
            ListTitleView(
                config: .text(
                    details.title,
                    accessory: ListTitleView.Accessory(
                        title: details.explorerButtonTitle,
                        action: details.onOpenExplorer
                    )
                )
            )
            .padding(.horizontal, Layout.horizontalPadding)

            VStack(spacing: 0) {
                ForEach(Array(details.items.enumerated()), id: \.element.id) { index, item in
                    NFTDetailsListItemCell(
                        item: item,
                        showsDivider: index < details.items.count - 1,
                        onCopy: onCopy
                    )
                }
            }
            .asCellsGroup(config: CellsGroupModifier.Config(horizontalPadding: 0))
            .padding(.horizontal, Layout.horizontalPadding)
        }
        .padding(.bottom, Layout.bottomPadding)
    }

    private enum Layout {
        static let horizontalPadding: CGFloat = 16
        static let bottomPadding: CGFloat = 16
    }
}

private struct NFTDetailsListItemCell: View {
    let item: NFTDetailsScreenState.Details.Item
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
                                ),
                                value: CellCenterPrimaryRow.ValueConfig(title: item.value)
                            )
                        )
                    )
                }
            }
        )
    }

    private var copyAction: (() -> Void)? {
        guard let copyValue = item.copyValue else {
            return nil
        }
        return {
            onCopy(copyValue)
        }
    }
}
