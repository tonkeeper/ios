import SwiftUI

public struct ButtonViewPreviews: View {
    @Environment(\.tkPalette) private var palette

    public init() {}

    public var body: some View {
        ScrollView(showsIndicators: false) {
            ListTitleView(
                config: .text("Buttons", accessory: nil)
            )
            VStack(spacing: 0) {
                VStack(alignment: .leading, spacing: Layout.sectionSpacing) {
                    stateSection(size: .small)
                    stateSection(size: .medium)
                    stateSection(size: .large)
                    overlaySection
                    destructiveSection
                }
                .padding(.horizontal, Layout.contentHorizontalPadding)
                .padding(.vertical, Layout.contentVerticalPadding)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            ListTitleView(
                config: .text("Button States", accessory: nil)
            )
            HStack {
                ButtonView(
                    config: .init(
                        title: "Text",
                        size: .small,
                        appearance: .secondary,
                        action: {}
                    )
                )
                ButtonView(
                    config: .init(
                        title: "Text",
                        size: .small,
                        appearance: .secondary,
                        icon: ButtonView.Icon(
                            image: .TKUIKit.Icons.Size16.globe,
                            alignment: .leading
                        ),
                        action: {}
                    )
                )
                ButtonView(
                    config: .init(
                        title: "Text",
                        size: .small,
                        appearance: .secondary,
                        icon: ButtonView.Icon(
                            image: .TKUIKit.Icons.Size16.globe,
                            alignment: .trailing
                        ),
                        action: {}
                    )
                )
            }
            ListTitleView(
                config: .text("Attributed Strings", accessory: nil)
            )
            HStack {
                attributedStringButton(state: .active)
            }
        }
        .tkImmediateButtonPresses()
        .background(
            palette.background.page
                .ignoresSafeArea()
        )
    }
}

private extension ButtonViewPreviews {
    enum PreviewState: Equatable {
        case active
        case disabled
        case highlighted

        var modernButtonState: ButtonView.State? {
            switch self {
            case .active:
                nil
            case .disabled:
                .disabled
            case .highlighted:
                .highlighted
            }
        }
    }

    enum Layout {
        static let contentHorizontalPadding: CGFloat = 24
        static let contentVerticalPadding: CGFloat = 24
        static let rowSpacing: CGFloat = 16
        static let sectionSpacing: CGFloat = 24
        static let buttonSpacing: CGFloat = 16
    }

    func stateSection(size: ButtonView.Size) -> some View {
        VStack(alignment: .leading, spacing: Layout.rowSpacing) {
            stateRow(size: size, appearance: .primary)
            stateRow(size: size, appearance: .secondary)
            stateRow(size: size, appearance: .tertiary)
        }
    }

    func stateRow(
        size: ButtonView.Size,
        appearance: ButtonView.Appearance
    ) -> some View {
        HStack(alignment: .top, spacing: Layout.buttonSpacing) {
            previewButton(
                size: size,
                appearance: appearance,
                state: .active
            )

            previewButton(
                size: size,
                appearance: appearance,
                state: .disabled
            )

            Spacer(minLength: 0)

            previewButton(
                size: size,
                appearance: appearance,
                state: .highlighted
            )
        }
    }

    var overlaySection: some View {
        VStack(alignment: .leading, spacing: Layout.rowSpacing) {
            previewButton(
                size: .small,
                appearance: .overlay,
                state: .active
            )

            previewButton(
                size: .medium,
                appearance: .overlay,
                state: .active
            )

            previewButton(
                size: .large,
                appearance: .overlay,
                state: .active
            )
        }
    }

    var destructiveSection: some View {
        HStack(alignment: .top, spacing: Layout.buttonSpacing) {
            previewButton(
                size: .small,
                appearance: .destructive,
                state: .active
            )

            previewButton(
                size: .small,
                appearance: .destructive,
                state: .highlighted
            )

            Spacer(minLength: 0)
        }
    }

    func previewButton(
        size: ButtonView.Size,
        appearance: ButtonView.Appearance,
        state: PreviewState
    ) -> some View {
        ButtonView(
            config: .init(
                title: "Label",
                size: size,
                appearance: appearance,
                action: {}
            )
        )
        .modernButtonPreviewState(state.modernButtonState)
        .disabled(state == .disabled)
    }

    func attributedStringButton(state: PreviewState) -> some View {
        ButtonView(
            config: .init(
                title: transactionTitle,
                size: .small,
                appearance: .secondary,
                icon: ButtonView.Icon(
                    image: .TKUIKit.Icons.Size16.globe,
                    alignment: .leading
                ),
                action: {}
            )
        )
        .modernButtonPreviewState(state.modernButtonState)
    }

    var transactionTitle: AttributedString {
        var title = AttributedString("Transaction ")
        var hash = AttributedString("4d1e1608")
        hash.foregroundColor = palette.button.secondaryForeground.opacity(0.48)
        title.append(hash)
        return title
    }
}

#Preview {
    ButtonViewPreviews()
        .clipShape(
            RoundedRectangle(
                cornerRadius: 20,
                style: .continuous
            )
        )
        .debugPreview(background: .page)
        .tkThemed()
}
