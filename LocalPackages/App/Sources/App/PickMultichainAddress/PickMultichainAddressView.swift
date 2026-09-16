import SwiftUI
import TKLocalize
import TKUIKit

struct PickMultichainAddressScreen: View {
    @ObservedObject var viewModel: PickMultichainAddressViewModelImplementation

    var body: some View {
        VStack(spacing: 0) {
            DefaultModalCardHeader(
                config: DefaultModalCardHeader.Config(
                    title: DefaultModalCardHeader.Title(
                        text: TKLocales.Receive.Multichain.NetworkPicker.title
                    ),
                    subtitle: DefaultModalCardHeader.Subtitle(
                        text: TKLocales.Receive.Multichain.NetworkPicker.subtitle
                    ),
                    rightIcon: .close(
                        onTap: { _ in
                            viewModel.close()
                        }
                    )
                )
            )
            .fixedSize(horizontal: false, vertical: true)

            ScrollView(showsIndicators: false) {
                PickMultichainAddressView(viewModel: viewModel)
                    .padding(.bottom, Layout.bottomPadding)
            }
            .tkImmediateButtonPresses()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(.backgroundPage)
        .ignoresSafeArea(.container, edges: .top)
    }

    private enum Layout {
        static let bottomPadding: CGFloat = 24
    }
}

struct PickMultichainAddressView: View {
    @ObservedObject var viewModel: PickMultichainAddressViewModelImplementation

    var body: some View {
        LazyVStack(spacing: 0) {
            ForEach(Array(viewModel.items.enumerated()), id: \.element.id) { index, item in
                PickMultichainAddressRowView(
                    item: item,
                    onSelect: { viewModel.selectAddress(item.address) },
                    onCopy: { viewModel.copyAddress(item.address) },
                    showDivider: index < viewModel.items.count - 1
                )
            }
        }
        .asCellsGroup()
        .padding(.top, PickMultichainAddressPresentation.contentVerticalPadding)
    }
}

struct PickMultichainAddressRowView: View {
    let item: PickMultichainAddressItem
    let onSelect: () -> Void
    let onCopy: () -> Void
    let showDivider: Bool

    var body: some View {
        Cell(
            config: .init(
                style: .grouped,
                showsDivider: showDivider,
                action: onSelect
            ),
            leading: {
                CellAssetLeading {
                    AssetAvatarView(
                        imageSource: .image(item.icon)
                    )
                }
            },
            center: {
                CellCenter(
                    primaryRow: CellCenterPrimaryRow(
                        config: .content(
                            .init(
                                title: item.title,
                                tags: item.versionTag.map { [.tag(text: $0)] }
                            )
                        )
                    ),
                    secondaryRow: CellCenterSecondaryRow(
                        config: .content(
                            .init(
                                value: .init(
                                    title: item.shortAddress
                                )
                            )
                        )
                    )
                )
            },
            trailing: {
                HStack(alignment: .center, spacing: 0) {
                    Button(action: onSelect) {
                        CellTrailingAccessory(
                            config: .init(
                                color: .iconPrimary,
                                icon: SwiftUI.Image.TKUIKit.Icons.Size28.qrCodeAlternate
                            )
                        )
                    }
                    .buttonStyle(.plain)

                    Button(action: onCopy) {
                        CellTrailingAccessory(
                            config: .init(
                                color: .iconPrimary,
                                icon: SwiftUI.Image.TKUIKit.Icons.Size28.copyOutline
                            )
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        )
        .frame(maxWidth: .infinity)
    }
}
