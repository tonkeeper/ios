import Kingfisher
import SwiftUI

public struct WalletBalanceUpdatesSwiftUIViewConfig: Hashable {
    public var title: String
    public var icon: TKImage?

    public init(
        title: String,
        icon: TKImage? = nil
    ) {
        self.title = title
        self.icon = icon
    }
}

struct WalletBalanceUpdatesSwiftUIView: View {
    var config: WalletBalanceUpdatesSwiftUIViewConfig
    private let action: (() -> Void)?

    init(
        config: WalletBalanceUpdatesSwiftUIViewConfig,
        action: (() -> Void)? = nil
    ) {
        self.config = config
        self.action = action
    }

    var body: some View {
        SwiftUI.Button(action: {
            action?()
        }) {
            content
        }
        .buttonStyle(WalletBalanceUpdatesSwiftUIViewButtonStyle())
    }
}

private extension WalletBalanceUpdatesSwiftUIView {
    var content: some View {
        HStack(alignment: .center, spacing: 0) {
            if let icon = config.icon, icon.isVisible {
                iconView(icon)
                    .frame(
                        width: Layout.iconSide,
                        height: Layout.iconSide
                    )
                    .padding(.trailing, Layout.iconTrailingPadding)
            }

            Text(config.title)
                .textStyle(.body3Alternate)
                .foregroundStyle(.textPrimary)
                .lineLimit(1)
                .truncationMode(.tail)

            SwiftUI.Image.TKUIKit.Icons.Size16.chevronRight
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .foregroundStyle(.iconTertiary)
                .frame(
                    width: Layout.chevronSide,
                    height: Layout.chevronSide
                )
        }
        .frame(height: Layout.contentHeight)
        .padding(.bottom, Layout.bottomPadding)
        .frame(
            maxWidth: .infinity,
            alignment: .center
        )
        .frame(height: Layout.height, alignment: .top)
        .contentShape(Rectangle())
    }

    @ViewBuilder
    func iconView(_ icon: TKImage) -> some View {
        switch icon {
        case let .image(image):
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .foregroundStyle(.accentBlue)
            }
        case let .urlImage(url):
            if let url {
                WalletBalanceUpdatesURLIconView(url: url)
            }
        }
    }
}

private struct WalletBalanceUpdatesURLIconView: View {
    @Environment(\.tkPalette) private var palette
    let url: URL
    @State private var didFail = false

    var body: some View {
        Group {
            if didFail {
                placeholder
            } else {
                KFImage
                    .url(url)
                    .setProcessor(
                        DownsamplingImageProcessor(
                            size: CGSize(
                                width: WalletBalanceUpdatesSwiftUIView.Layout.iconSide * UIScreen.main.scale,
                                height: WalletBalanceUpdatesSwiftUIView.Layout.iconSide * UIScreen.main.scale
                            )
                        )
                    )
                    .loadDiskFileSynchronously()
                    .fade(duration: 0)
                    .placeholder {
                        placeholder
                    }
                    .onSuccess { _ in
                        didFail = false
                    }
                    .onFailure { _ in
                        didFail = true
                    }
                    .cancelOnDisappear(true)
                    .resizable()
                    .scaledToFit()
            }
        }
    }

    private var placeholder: some View {
        palette.background.contentTint
    }
}

private struct WalletBalanceUpdatesSwiftUIViewButtonStyle: SwiftUI.ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .tkTapAnimation(isPressed: configuration.isPressed)
    }
}

private extension WalletBalanceUpdatesSwiftUIView {
    enum Layout {
        static let height: CGFloat = 28
        static let contentHeight: CGFloat = 20
        static let bottomPadding: CGFloat = 8
        static let iconSide: CGFloat = 20
        static let iconTrailingPadding: CGFloat = 6
        static let chevronSide: CGFloat = 16
    }
}

private extension TKImage {
    var isVisible: Bool {
        switch self {
        case let .image(image):
            image != nil
        case let .urlImage(url):
            url != nil
        }
    }
}
