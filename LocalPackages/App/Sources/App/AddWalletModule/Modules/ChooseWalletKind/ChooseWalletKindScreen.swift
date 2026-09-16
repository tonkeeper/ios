import SwiftUI
import TKCore
import TKLocalize
import TKUIKit

struct ChooseWalletKindScreen: View {
    @ObservedObject var viewModel: ChooseWalletKindViewModel

    var body: some View {
        ZStack(alignment: .bottom) {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    header
                    walletsList
                }
                .padding(.bottom, Layout.scrollBottomPadding)
            }
            .tkImmediateButtonPresses()

            actionBar
        }
        .background(.backgroundPage)
    }
}

private extension ChooseWalletKindScreen {
    var header: some View {
        VStack(spacing: Layout.headerSpacing) {
            Text(TKLocales.ChooseWalletKind.title)
                .textStyle(.h2)
                .foregroundStyle(.textPrimary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            Text(TKLocales.ChooseWalletKind.description)
                .textStyle(.body1)
                .foregroundStyle(.textSecondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, Layout.headerHorizontalPadding)
        .padding(.top, Layout.headerTopPadding)
        .padding(.bottom, Layout.headerBottomPadding)
    }

    var walletsList: some View {
        LazyVStack(spacing: 0) {
            ForEach(Array(viewModel.rows.enumerated()), id: \.element.id) { index, row in
                ChooseWalletKindWalletCell(
                    row: row,
                    isSelected: viewModel.isSelected(row),
                    showsDivider: index < viewModel.rows.count - 1,
                    onTap: {
                        viewModel.selectKind(row.id)
                    }
                )
            }
        }
        .asCellsGroup()
    }

    var actionBar: some View {
        ZStack {
            ButtonView(
                config: ButtonView.Config(
                    title: TKLocales.Actions.continueAction,
                    size: .large,
                    layoutMode: .fill,
                    appearance: .primary,
                    action: {
                        viewModel.continueImport()
                    }
                )
            )
            .opacity(viewModel.showsContinueLoader ? 0 : 1)
            .disabled(viewModel.isContinueInProgress)

            if viewModel.showsContinueLoader {
                CircularLoader(
                    mode: .indeterminate,
                    preset: .medium
                )
            }
        }
        .padding(Layout.actionButtonPadding)
        .background(.backgroundPage.opacity(0.96), ignoresSafeAreaEdges: .bottom)
    }

    enum Layout {
        static let headerSpacing: CGFloat = 4
        static let headerHorizontalPadding: CGFloat = 32
        static let headerTopPadding: CGFloat = -1
        static let headerBottomPadding: CGFloat = 30
        static let scrollBottomPadding: CGFloat = 96
        static let actionButtonPadding = EdgeInsets(top: 16, leading: 32, bottom: 32, trailing: 32)
    }
}
