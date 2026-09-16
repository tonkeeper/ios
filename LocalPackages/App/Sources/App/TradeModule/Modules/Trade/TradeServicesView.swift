import SwiftUI
import TKUIKit

struct TradeServicesView: View {
    let services: [TradeViewModel.ServiceViewData]
    let onOpenService: (TradeViewModel.ServiceViewData) -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            ForEach(services) { service in
                Button {
                    onOpenService(service)
                } label: {
                    serviceView(service)
                }
                .buttonStyle(ServiceCardHighlightStyle())
                .frame(width: Layout.itemWidth)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, Layout.horizontalPadding)
        .padding(.bottom, Layout.bottomPadding)
    }

    private func serviceView(_ service: TradeViewModel.ServiceViewData) -> some View {
        VStack(spacing: Layout.contentSpacing) {
            ZStack {
                RoundedRectangle(cornerRadius: Layout.thumbCornerRadius, style: .continuous)
                    .fill(.backgroundContent)

                SwiftUI.Image(uiImage: service.icon)
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
                    .foregroundStyle(.accentBlue)
                    .frame(width: Layout.iconSize, height: Layout.iconSize)
            }
            .frame(width: Layout.thumbSize, height: Layout.thumbSize)

            Text(service.title)
                .textStyle(.body3)
                .foregroundStyle(.textPrimary)
                .lineLimit(1)
                .frame(maxWidth: .infinity)
        }
        .padding(.horizontal, Layout.itemHorizontalPadding)
        .padding(.vertical, Layout.itemVerticalPadding)
    }
}

private extension TradeServicesView {
    enum Layout {
        static let bottomPadding: CGFloat = 12
        static let contentSpacing: CGFloat = 7
        static let horizontalPadding: CGFloat = 12
        static let iconSize: CGFloat = 34
        static let itemWidth: CGFloat = 89
        static let itemHorizontalPadding: CGFloat = 2
        static let itemVerticalPadding: CGFloat = 8
        static let thumbCornerRadius: CGFloat = 16
        static let thumbSize: CGFloat = 64
    }
}
