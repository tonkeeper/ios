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
        .tkThemed()
}
