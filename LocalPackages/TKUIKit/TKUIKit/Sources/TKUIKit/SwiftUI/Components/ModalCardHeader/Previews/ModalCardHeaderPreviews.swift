import SwiftUI

public struct ModalCardHeaderPreviews: View {
    @Environment(\.tkPalette) private var palette

    public init() {}

    public var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 16) {
                DefaultModalCardHeader(
                    config: DefaultModalCardHeader.Config(
                        leftIcon: .close(),
                        title: DefaultModalCardHeader.Title(
                            text: "Title",
                            alignment: .center
                        ),
                        rightIcon: .close()
                    )
                )
                DefaultModalCardHeader(
                    config: DefaultModalCardHeader.Config(
                        leftIcon: .close(),
                        title: DefaultModalCardHeader.Title(
                            text: "A long header title that wraps onto multiple lines",
                            alignment: .center
                        ),
                        subtitle: DefaultModalCardHeader.Subtitle(
                            text: "A long description that wraps onto multiple lines without expanding the header to the available height"
                        ),
                        rightIcon: .close()
                    )
                )
                DefaultModalCardHeader(
                    config: DefaultModalCardHeader.Config(
                        leftIcon: .close(),
                        title: DefaultModalCardHeader.Title(
                            text: "Tesla",
                            alignment: .center
                        ),
                        subtitle: DefaultModalCardHeader.Subtitle(
                            text: "Tokenized Stock",
                            color: .accentBlue,
                            icon: nil
                        ),
                        rightIcon: .close()
                    )
                )
                DefaultModalCardHeader(
                    config: DefaultModalCardHeader.Config(
                        leftIcon: .close(),
                        title: DefaultModalCardHeader.Title(
                            text: "Tesla",
                            alignment: .center
                        ),
                        subtitle: DefaultModalCardHeader.Subtitle(
                            text: "Tokenized Stock",
                            color: .accentBlue,
                            icon: DefaultModalCardHeader.SubtitleIcon(
                                image: .TKUIKit.Icons.Size12.informationCircle,
                                size: 12,
                                topPadding: 3
                            )
                        ),
                        rightIcon: .close()
                    )
                )

                DefaultModalCardHeader(
                    config: DefaultModalCardHeader.Config(
                        title: DefaultModalCardHeader.Title(
                            text: "Title",
                            alignment: .leading
                        ),
                        rightIcon: .close()
                    )
                )
                DefaultModalCardHeader(
                    config: DefaultModalCardHeader.Config(
                        rightIcon: .close()
                    )
                )
                DefaultModalCardHeader(
                    config: DefaultModalCardHeader.Config(
                        rightIcon: .close(),
                        height: .compact
                    )
                )
            }
        }
        .tkImmediateButtonPresses()
        .background(
            palette.background.content
                .ignoresSafeArea()
        )
    }
}

#Preview {
    ModalCardHeaderPreviews()
        .debugPreview(background: .page)
        .tkPreviewLiquidGlass(false)
        .tkThemed()
}

@available(iOS 17.0, *)
#Preview("Liquid Glass", traits: .fixedLayout(width: 390, height: 358)) {
    VStack(spacing: 10) {
        DefaultModalCardHeader(
            config: DefaultModalCardHeader.Config(
                leftIcon: .back(),
                title: DefaultModalCardHeader.Title(text: "Tesla"),
                rightIcon: DefaultModalCardHeader.Icon(
                    image: .TKUIKit.Icons.Size16.ellipses,
                    size: 16,
                    padding: 8,
                    liquidGlassImage: .TKUIKit.Icons.Size28.ellipses,
                    onTap: { _ in }
                ),
                secondaryRightIcon: DefaultModalCardHeader.Icon(
                    image: .TKUIKit.Icons.Size16.star,
                    size: 16,
                    padding: 8,
                    liquidGlassImage: .TKUIKit.Icons.Size28.star,
                    onTap: { _ in }
                )
            )
        )
        DefaultModalCardHeader(
            config: DefaultModalCardHeader.Config(
                leftIcon: .close(),
                title: DefaultModalCardHeader.Title(text: "Title"),
                rightIcon: .close()
            )
        )
        DefaultModalCardHeader(
            config: DefaultModalCardHeader.Config(
                title: DefaultModalCardHeader.Title(text: "Title", alignment: .leading),
                rightIcon: .close()
            )
        )
        DefaultModalCardHeader(config: DefaultModalCardHeader.Config(rightIcon: .close()))
        DefaultModalCardHeader(config: DefaultModalCardHeader.Config(rightIcon: .close(), height: .compact))
    }
    .frame(maxHeight: .infinity, alignment: .top)
    .background(.backgroundContent)
    .tkPreviewLiquidGlass(true)
    .tkPreviewTheme(.deepBlue)
}

@available(iOS 17.0, *)
#Preview("Liquid Glass: lottie icon and wrapped title", traits: .fixedLayout(width: 390, height: 234)) {
    VStack(spacing: 10) {
        DefaultModalCardHeader(
            config: DefaultModalCardHeader.Config(
                leftIcon: .back(),
                title: DefaultModalCardHeader.Title(text: "Tesla"),
                rightIcon: DefaultModalCardHeader.Icon(
                    image: .TKUIKit.Icons.Size16.ellipses,
                    size: 16,
                    padding: 8,
                    liquidGlassImage: .TKUIKit.Icons.Size28.ellipses,
                    onTap: { _ in }
                ),
                secondaryRightIcon: DefaultModalCardHeader.Icon(
                    image: .TKUIKit.Icons.Size16.star,
                    size: 16,
                    padding: 8,
                    lottie: DefaultModalCardHeader.Lottie(resource: .favorite, isOn: false),
                    liquidGlassImage: .TKUIKit.Icons.Size28.star,
                    onTap: { _ in }
                )
            )
        )
        DefaultModalCardHeader(
            config: DefaultModalCardHeader.Config(
                leftIcon: .close(),
                title: DefaultModalCardHeader.Title(text: "A long header title that wraps onto two lines"),
                rightIcon: DefaultModalCardHeader.Icon(
                    image: .TKUIKit.Icons.Size16.star,
                    size: 16,
                    padding: 8,
                    lottie: DefaultModalCardHeader.Lottie(resource: .favorite, isOn: true),
                    liquidGlassImage: .TKUIKit.Icons.Size28.star,
                    onTap: { _ in }
                )
            )
        )
        DefaultModalCardHeader(
            config: DefaultModalCardHeader.Config(
                title: DefaultModalCardHeader.Title(text: "Compact"),
                height: .compact
            )
        )
    }
    .frame(maxHeight: .infinity, alignment: .top)
    .background(.backgroundContent)
    .tkPreviewLiquidGlass(true)
    .tkPreviewTheme(.deepBlue)
}
