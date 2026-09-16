import KeeperCore
import SwiftUI
import TKLocalize
import TKUIKit
import UIKit

struct SettingsConnectedAppsScreen: View {
    @ObservedObject var viewModel: SettingsConnectedAppsViewModel
    var body: some View {
        VStack(spacing: 0) {
            header

            if viewModel.canDisconnectAllApps {
                disconnectAllButton
            }

            content
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(.backgroundPage)
        .task {
            viewModel.start()
        }
    }
}

private extension SettingsConnectedAppsScreen {
    var header: some View {
        DefaultModalCardHeader(
            config: DefaultModalCardHeader.Config(
                leftIcon: DefaultModalCardHeader.Icon(
                    image: .TKUIKit.Icons.Size16.chevronLeft,
                    size: 16,
                    padding: 8,
                    onTap: { _ in
                        viewModel.close()
                    }
                ),
                title: DefaultModalCardHeader.Title(
                    text: TKLocales.Settings.Items.connectedApps
                ),
                height: .atLeast(Layout.headerHeight)
            )
        )
        .fixedSize(horizontal: false, vertical: true)
    }

    var disconnectAllButton: some View {
        ButtonView(
            config: ButtonView.Config(
                title: TKLocales.Settings.ConnectedApps.disconnectAllApps,
                size: .large,
                layoutMode: .fill,
                appearance: .secondary,
                action: viewModel.disconnectAllApps
            )
        )
        .padding(.horizontal, Layout.horizontalPadding)
        .padding(.bottom, Layout.buttonBottomPadding)
    }

    @ViewBuilder
    var content: some View {
        switch viewModel.state {
        case .loading:
            transparentContentPlaceholder
        case let .loaded(dApps):
            if dApps.isEmpty {
                emptyView
            } else {
                dAppsList(dApps)
            }
        }
    }

    var transparentContentPlaceholder: some View {
        Color.clear
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            .padding(.horizontal, Layout.horizontalPadding)
    }

    var emptyView: some View {
        PlaceholderView(
            config: PlaceholderView.Config(
                lottieResource: .apps,
                title: TKLocales.Browser.ConnectedApps.emptyTitle,
                subtitle: TKLocales.Browser.ConnectedApps.emptyDescription
            )
        )
        .padding(.horizontal, Layout.horizontalPadding)
        .padding(.bottom, Layout.emptyBottomPadding)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
    }

    func dAppsList(_ dApps: [SettingsConnectedAppsViewModel.DApp]) -> some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 0) {
                ForEach(Array(dApps.enumerated()), id: \.element.id) { index, dApp in
                    DAppCell(
                        content: DAppCellContent(
                            name: dApp.name,
                            url: dApp.host,
                            extraInfo: dApp.extraInfo?.cellExtraInfo,
                            image: dApp.image,
                            sourceAccent: dApp.sourceAccent,
                            showSeparator: index < dApps.count - 1
                        ),
                        onCancel: {
                            viewModel.disconnect(dApp: dApp)
                        }
                    )
                }
            }
            .background(.backgroundContent)
            .clipShape(
                RoundedRectangle(
                    cornerRadius: Layout.listCornerRadius,
                    style: .continuous
                )
            )
            .padding(.horizontal, Layout.horizontalPadding)
        }
        .tkImmediateButtonPresses()
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    enum Layout {
        static let headerHeight: CGFloat = 64
        static let horizontalPadding: CGFloat = 16
        static let buttonBottomPadding: CGFloat = 16
        static let emptyBottomPadding: CGFloat = 128
        static let listCornerRadius: CGFloat = 16
    }
}
