import SwiftUI
import TKUIKit
import UIKit

public struct TradeServiceItem: Identifiable {
    public enum Kind: String {
        case tokens
        case perps
        case stocks
        case etfs
    }

    public let kind: Kind
    public let title: String
    public let icon: UIImage
    public var id: String {
        kind.rawValue
    }

    public init(kind: Kind, title: String, icon: UIImage) {
        self.kind = kind
        self.title = title
        self.icon = icon
    }
}

public struct TradeServicesView: View {
    let services: [TradeServiceItem]
    let onOpenService: (TradeServiceItem) -> Void

    public init(services: [TradeServiceItem], onOpenService: @escaping (TradeServiceItem) -> Void) {
        self.services = services
        self.onOpenService = onOpenService
    }

    public var body: some View {
        HStack(alignment: .top, spacing: 0) {
            ForEach(services) { service in
                Button {
                    onOpenService(service)
                } label: {
                    serviceView(service)
                }
                .buttonStyle(ServiceCardHighlightStyle())
                .frame(maxWidth: .infinity)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, Layout.horizontalPadding)
        .padding(.bottom, Layout.bottomPadding)
    }

    private func serviceView(_ service: TradeServiceItem) -> some View {
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
        static let contentSpacing: CGFloat = 8
        static let horizontalPadding: CGFloat = 12
        static let iconSize: CGFloat = 34
        static let itemHorizontalPadding: CGFloat = 2
        static let itemVerticalPadding: CGFloat = 8
        static let thumbCornerRadius: CGFloat = 16
        static let thumbSize: CGFloat = 64
    }
}
