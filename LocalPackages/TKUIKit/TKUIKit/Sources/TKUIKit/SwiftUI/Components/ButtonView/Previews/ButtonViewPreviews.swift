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

/// The design system's button grid: every type in its active, highlighted and disabled state, in all three sizes.
private struct ButtonViewStatesGrid: View {
    private let appearances: [ButtonView.Appearance] = [
        .primary, .primaryDestructive, .secondary, .tertiary, .destructive, .attention, .overlay,
    ]
    private let states: [ButtonView.State?] = [nil, .highlighted, .disabled]

    var body: some View {
        VStack(alignment: .leading, spacing: 40) {
            ForEach([ButtonView.Size.large, .medium, .small], id: \.self) { size in
                VStack(alignment: .leading, spacing: 16) {
                    ForEach(appearances.indices, id: \.self) { index in
                        HStack(spacing: 0) {
                            ForEach(states.indices, id: \.self) { stateIndex in
                                button(size: size, appearance: appearances[index], state: states[stateIndex])
                                    .frame(width: 116, alignment: .leading)
                            }
                        }
                    }
                }
            }
        }
        .padding(.leading, 33)
        .padding(.top, 24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(.backgroundPage)
    }

    private func button(size: ButtonView.Size, appearance: ButtonView.Appearance, state: ButtonView.State?) -> some View {
        ButtonView(config: .init(title: "Label", size: size, appearance: appearance, action: {}))
            .modernButtonPreviewState(state)
            .disabled(state == .disabled)
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
        .tkPreviewLiquidGlass(false)
        .tkThemed()
}

@available(iOS 17.0, *)
#Preview("Liquid Glass", traits: .fixedLayout(width: 390, height: 1412)) {
    ButtonViewStatesGrid()
        .tkPreviewLiquidGlass(true)
        .tkPreviewTheme(.deepBlue)
}

@available(iOS 17.0, *)
#Preview("Liquid Glass: icon and loader", traits: .sizeThatFitsLayout) {
    let icon = ButtonView.Icon(image: .TKUIKit.Icons.Size16.globe)
    VStack(spacing: 16) {
        ButtonView(config: .init(title: "Label", size: .large, appearance: .primary, icon: icon, action: {}))
        ButtonView(config: .init(title: "Label", size: .large, appearance: .primary, icon: icon, action: {}))
            .disabled(true)
        ButtonView(config: .init(title: "Label", size: .large, appearance: .primary, showsLoader: true, action: {}))
            .disabled(true)
    }
    .padding()
    .background(.backgroundPage)
    .tkPreviewLiquidGlass(true)
    .tkPreviewTheme(.light)
}
