import SwiftUI
import TKUIKit

struct RampPaymentMethodView: View {
    @ObservedObject var viewModel: RampPaymentMethodViewModel

    var body: some View {
        VStack(spacing: 0) {
            DefaultModalCardHeader(
                config: DefaultModalCardHeader.Config(
                    leftIcon: .init(
                        image: .TKUIKit.Icons.Size16.chevronLeft,
                        size: 16,
                        padding: 8,
                        onTap: { _ in
                            viewModel.back()
                        }
                    ),
                    title: DefaultModalCardHeader.Title(
                        text: viewModel.screenTitle
                    ),
                    subtitle: DefaultModalCardHeader.Subtitle(
                        text: viewModel.currencySubtitleCaption,
                        color: .textSecondary,
                        accentText: viewModel.currencyCode,
                        accentColor: .accentBlue,
                        icon: .init(
                            image: .TKUIKit.Icons.Size16.switch,
                            size: 12,
                            topPadding: 2
                        ),
                        onTap: {
                            viewModel.tapCurrency()
                        }
                    ),
                    rightIcon: .close(
                        onTap: { _ in
                            viewModel.close()
                        }
                    ),
                    height: .compact
                )
            )
            .fixedSize(horizontal: false, vertical: true)

            content
                .padding(.top, 8)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(.backgroundPage)
    }
}

private extension RampPaymentMethodView {
    @ViewBuilder
    var content: some View {
        switch viewModel.state {
        case .loading:
            ProgressView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        case .loaded, .failed:
            if let placeholderKind = viewModel.placeholderKind {
                placeholderView(kind: placeholderKind)
            } else {
                rowsList
            }
        }
    }

    func placeholderView(kind: PaymentMethodPlaceholderOverlayKind) -> some View {
        PaymentMethodPlaceholderOverlayRootView(
            kind: kind,
            didTapRetry: {
                viewModel.retry()
            }
        )
        .padding(.horizontal, 32)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
    }

    var rowsList: some View {
        VStack(spacing: 0) {
            ForEach(Array(viewModel.rows.enumerated()), id: \.element.id) { index, row in
                RampPaymentMethodCell(
                    row: row,
                    showsDivider: index < viewModel.rows.count - 1,
                    onTap: {
                        viewModel.select(row: row)
                    }
                )
            }
        }
        .asCellsGroup()
        .padding(.bottom, 16)
    }
}
