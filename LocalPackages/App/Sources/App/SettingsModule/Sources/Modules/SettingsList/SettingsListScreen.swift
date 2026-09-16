import SwiftUI
import TKUIKit

struct SettingsListScreen: View {
    @ObservedObject var viewModel: SettingsListViewModel

    var body: some View {
        VStack(spacing: 0) {
            header

            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    ForEach(Array(viewModel.sections.enumerated()), id: \.offset) { _, section in
                        sectionView(section)
                            .padding(.bottom, Layout.sectionBottomPadding)
                    }
                }
                .padding(.bottom, Layout.listBottomPadding)
            }
            .tkImmediateButtonPresses()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .ignoresSafeArea(.all, edges: .bottom)
        .background(.backgroundPage)
        .task {
            viewModel.start()
        }
    }
}

private extension SettingsListScreen {
    var header: some View {
        DefaultModalCardHeader(
            config: .push(
                title: viewModel.title,
                onBack: {
                    viewModel.close()
                }
            )
        )
        .fixedSize(horizontal: false, vertical: true)
    }

    @ViewBuilder
    func sectionView(_ section: SettingsListSection) -> some View {
        switch section {
        case let .items(itemsSection):
            itemsSectionView(itemsSection)
        case let .appInformation(information):
            SettingsListAppInformationView(
                information: information,
                onDevMenuActivation: {
                    viewModel.openDevMenu()
                }
            )
        }
    }

    func itemsSectionView(_ section: SettingsListItemsSection) -> some View {
        VStack(spacing: 0) {
            if let header = section.header {
                sectionHeaderView(header)
            }

            ForEach(Array(listItemRuns(section.items).enumerated()), id: \.offset) { _, run in
                runView(run)
            }

            if let footer = section.footer {
                sectionFooterView(footer)
            }
        }
    }

    @ViewBuilder
    func runView(_ run: ItemsRun) -> some View {
        switch run {
        case let .listItems(items):
            VStack(spacing: 0) {
                ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                    SettingsListItemCell(
                        item: item,
                        showsDivider: index < items.count - 1
                    )
                }
            }
            .asCellsGroup()
        case let .banner(banner):
            NotificationBanner(
                content: banner.content,
                onButtonTap: banner.onButtonTap
            )
            .padding(.horizontal, Layout.horizontalPadding)
        case let .button(button):
            ButtonView(
                config: ButtonView.Config(
                    title: button.title,
                    size: .large,
                    layoutMode: .fill,
                    appearance: button.appearance,
                    action: button.action
                )
            )
            .padding(.horizontal, Layout.horizontalPadding)
        }
    }

    func sectionHeaderView(_ header: SettingsListSectionHeader) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(header.title)
                .textStyle(.h3)
                .foregroundStyle(.textPrimary)
                .fixedSize(horizontal: false, vertical: true)

            if let caption = header.caption {
                Text(caption)
                    .textStyle(.body2)
                    .foregroundStyle(.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, Layout.headerHorizontalPadding)
        .padding(.top, Layout.headerTopPadding)
        .padding(.bottom, Layout.headerBottomPadding)
    }

    func sectionFooterView(_ footer: String) -> some View {
        Text(footer)
            .textStyle(.body2)
            .foregroundStyle(.textSecondary)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, Layout.footerHorizontalPadding)
            .padding(.top, Layout.footerTopPadding)
            .padding(.bottom, Layout.footerBottomPadding)
    }

    enum ItemsRun {
        case listItems([SettingsListItem])
        case banner(SettingsListBannerItem)
        case button(SettingsListButtonItem)
    }

    func listItemRuns(_ items: [SettingsListItemsSectionItem]) -> [ItemsRun] {
        var runs = [ItemsRun]()
        var currentListItems = [SettingsListItem]()

        func flushListItems() {
            guard !currentListItems.isEmpty else { return }
            runs.append(.listItems(currentListItems))
            currentListItems = []
        }

        for item in items {
            switch item {
            case let .listItem(listItem):
                currentListItems.append(listItem)
            case let .banner(banner):
                flushListItems()
                runs.append(.banner(banner))
            case let .button(button):
                flushListItems()
                runs.append(.button(button))
            }
        }
        flushListItems()

        return runs
    }

    enum Layout {
        static let horizontalPadding: CGFloat = 16
        static let sectionBottomPadding: CGFloat = 16
        static let listBottomPadding: CGFloat = 21
        static let headerHorizontalPadding: CGFloat = 16
        static let headerTopPadding: CGFloat = 14
        static let headerBottomPadding: CGFloat = 13
        static let footerHorizontalPadding: CGFloat = 16
        static let footerTopPadding: CGFloat = 12
        static let footerBottomPadding: CGFloat = 16
    }
}
