import SwiftUI
import TKLocalize
import TKUIKit

struct ChooseWalletVersionScreen: View {
    @ObservedObject var viewModel: ChooseWalletVersionViewModel
    @State private var isInfoSheetPresented = false

    var body: some View {
        ZStack(alignment: .bottom) {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    header
                    walletsList
                    learnMoreButton
                }
                .padding(.bottom, Layout.scrollBottomPadding)
            }
            .tkImmediateButtonPresses()

            actionBar
        }
        .background(.backgroundPage)
        .tkBottomSheet(
            isPresented: $isInfoSheetPresented,
            header: { _ in
                TKBottomSheetHeaderConfiguration(
                    title: .empty,
                    contentInsets: UIEdgeInsets(
                        top: 16,
                        left: 16,
                        bottom: 8,
                        right: 16
                    )
                )
            },
            content: {
                BulletsInfoPopupView(
                    content: BulletsInfoPopupContent(
                        title: TKLocales.ChooseWalletVersion.infoTitle,
                        caption: TKLocales.ChooseWalletVersion.infoDescription,
                        captionStyle: .body2,
                        bullets: [
                            TKLocales.ChooseWalletVersion.w5Description,
                            TKLocales.ChooseWalletVersion.v4r2Description,
                        ]
                    ),
                    onPrimaryTap: {
                        isInfoSheetPresented = false
                    }
                )
            }
        )
    }
}

private extension ChooseWalletVersionScreen {
    var header: some View {
        VStack(spacing: Layout.headerSpacing) {
            Text(TKLocales.ChooseWalletVersion.title)
                .textStyle(.h2)
                .foregroundStyle(.textPrimary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            Text(TKLocales.ChooseWalletVersion.description)
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
                ChooseWalletVersionWalletCell(
                    row: row,
                    isSelected: viewModel.isSelected(row),
                    showsDivider: index < viewModel.rows.count - 1,
                    onTap: {
                        viewModel.selectWallet(id: row.id)
                    }
                )
            }
        }
        .asCellsGroup()
        .padding(.bottom, Layout.listBottomPadding)
    }

    var learnMoreButton: some View {
        Button {
            isInfoSheetPresented = true
        } label: {
            HStack(spacing: Layout.learnMoreSpacing) {
                SwiftUI.Image(uiImage: .TKUIKit.Icons.Size16.informationCircle)
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
                    .frame(width: Layout.learnMoreIconSize, height: Layout.learnMoreIconSize)
                    .foregroundStyle(.iconTertiary)

                Text(TKLocales.ChooseWalletVersion.learnMore)
                    .textStyle(.body2)
                    .foregroundStyle(.textSecondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, Layout.learnMoreHorizontalPadding)
            .padding(.bottom, Layout.learnMoreVerticalPadding)
        }
        .buttonStyle(.plain)
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
        static let listBottomPadding: CGFloat = 14
        static let learnMoreSpacing: CGFloat = 8
        static let learnMoreIconSize: CGFloat = 16
        static let learnMoreHorizontalPadding: CGFloat = 16
        static let learnMoreVerticalPadding: CGFloat = 11
        static let scrollBottomPadding: CGFloat = 96
        static let actionButtonPadding = EdgeInsets(top: 16, leading: 32, bottom: 32, trailing: 32)
    }
}
