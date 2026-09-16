import KeeperCore
import SwiftUI
import TKLocalize
import TKUIKit

struct AddWalletOptionPickerScreen: View {
    @ObservedObject var viewModel: AddWalletOptionPickerViewModelImplementation

    var body: some View {
        VStack(spacing: 0) {
            DefaultModalCardHeader(
                config: DefaultModalCardHeader.Config(
                    title: .empty,
                    rightIcon: .close { _ in
                        viewModel.close()
                    },
                    height: .compact
                )
            )
            .fixedSize(horizontal: false, vertical: true)

            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    titleDescription

                    LazyVStack(spacing: Layout.itemsSpacing) {
                        ForEach(viewModel.sections) { section in
                            if let header = section.header {
                                Text(header)
                                    .textStyle(.body1)
                                    .foregroundStyle(.textSecondary)
                                    .frame(maxWidth: .infinity)
                                    .multilineTextAlignment(.center)
                                    .padding(.top, Layout.sectionHeaderTopPadding)
                                    .padding(.bottom, Layout.sectionHeaderBottomPadding)
                            }

                            ForEach(section.items) { item in
                                AddWalletOptionPickerCell(
                                    item: item,
                                    onTap: {
                                        viewModel.selectItem(item)
                                    }
                                )
                                .padding(.horizontal, Layout.contentHorizontalPadding)
                            }
                        }
                    }
                }
                .padding(.bottom, Layout.contentBottomPadding)
            }
            .tkImmediateButtonPresses()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(.backgroundPage)
        .ignoresSafeArea(.container, edges: .top)
    }

    private var titleDescription: some View {
        VStack(spacing: Layout.titleDescriptionSpacing) {
            Text(TKLocales.AddWallet.title)
                .textStyle(.h2)
                .foregroundStyle(.textPrimary)

            Text(TKLocales.AddWallet.description)
                .textStyle(.body1)
                .foregroundStyle(.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .multilineTextAlignment(.center)
        .fixedSize(horizontal: false, vertical: true)
        .padding(.horizontal, Layout.contentHorizontalPadding)
        .padding(.bottom, Layout.titleDescriptionBottomPadding)
        .padding(.top, Layout.titleDescriptionTopPadding)
    }
}

private struct AddWalletOptionPickerCell: View {
    let item: AddWalletOptionPickerItem
    let onTap: () -> Void

    var body: some View {
        Cell(
            config: Cell.Config(action: onTap),
            leading: {
                SwiftUI.Image(uiImage: item.icon)
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
                    .foregroundStyle(.accentBlue)
                    .frame(width: Layout.iconSize, height: Layout.iconSize)
                    .padding(.leading, Layout.leadingInset)
                    .padding(.vertical, Layout.iconVerticalPadding)
            },
            center: {
                CellCenter(
                    primaryRow: {
                        title
                    },
                    secondaryRow: {
                        Text(item.subtitle)
                            .textStyle(.body2)
                            .foregroundStyle(.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    },
                    contentInsets: {
                        $0.trailing = Layout.centerTrailingInset
                    }
                )
            },
            trailing: {
                CellTrailingAccessory(
                    config: CellTrailingAccessory.Config(
                        color: .iconTertiary,
                        icon: SwiftUI.Image.TKUIKit.Icons.Size16.chevronRight,
                        iconSize: Layout.chevronSize
                    )
                )
            }
        )
        .asCellsGroup(config: .init(horizontalPadding: 0))
    }

    private var title: some View {
        HStack(spacing: 0) {
            titleText
                .textStyle(.label1)
                .foregroundStyle(.textPrimary)
                .fixedSize(horizontal: false, vertical: true)

            if let tag = item.tag {
                TKTagSwiftUIView(config: tag)
                    .padding(.bottom, Layout.tagBottomPadding)
                    .fixedSize()
            }

            Spacer(minLength: 0)
        }
    }

    private var titleText: Text {
        let title = Text(item.title)
        guard !item.chains.isEmpty else {
            return title
        }

        let networksImage = WalletMultichainPresentation.networksRowImage(chains: item.chains)
            .withRenderingMode(.alwaysOriginal)
        let networks = Text(SwiftUI.Image(uiImage: networksImage))
            .baselineOffset(Layout.networksBaselineOffset)

        return title + Text("  ") + networks
    }

    private enum Layout {
        static let iconSize: CGFloat = 28
        static let chevronSize: CGFloat = 16
        static let leadingInset: CGFloat = 16
        static let iconVerticalPadding: CGFloat = 14
        static let centerTrailingInset: CGFloat = 8
        static let tagBottomPadding: CGFloat = 2
        static let networksBaselineOffset: CGFloat = -3
    }
}

private extension AddWalletOptionPickerScreen {
    enum Layout {
        static let contentHorizontalPadding: CGFloat = 32
        static let titleDescriptionSpacing: CGFloat = 3
        static let titleDescriptionTopPadding: CGFloat = 16
        static let titleDescriptionBottomPadding: CGFloat = 32
        static let sectionHeaderTopPadding: CGFloat = 13
        static let sectionHeaderBottomPadding: CGFloat = 10
        static let itemsSpacing: CGFloat = 8
        static let contentBottomPadding: CGFloat = 32
    }
}
