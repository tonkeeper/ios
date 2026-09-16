import SwiftUI

private struct ModernButtonPreviewStateKey: EnvironmentKey {
    static let defaultValue: ButtonView.State? = nil
}

private struct ModernButtonStateKey: EnvironmentKey {
    static let defaultValue = ButtonView.State.normal
}

extension EnvironmentValues {
    var modernButtonPreviewState: ButtonView.State? {
        get { self[ModernButtonPreviewStateKey.self] }
        set { self[ModernButtonPreviewStateKey.self] = newValue }
    }

    var modernButtonState: ButtonView.State {
        get { self[ModernButtonStateKey.self] }
        set { self[ModernButtonStateKey.self] = newValue }
    }
}

extension View {
    func modernButtonPreviewState(_ state: ButtonView.State?) -> some View {
        environment(\.modernButtonPreviewState, state)
    }
}

private struct TitlePaddingModifier: ViewModifier {
    var config: ButtonView.Config

    func body(content: Content) -> some View {
        switch config.size {
        case .tab:
            content
                .frame(maxHeight: .infinity, alignment: .center)
                .padding(horizontalPaddingEdges, Layout.Tab.horizontalPadding)
        case .small:
            content
                .frame(maxHeight: .infinity, alignment: .center)
                .padding(horizontalPaddingEdges, 16)
        case .medium:
            content
                .padding(.bottom, 2)
                .frame(maxHeight: .infinity, alignment: .center)
                .padding(horizontalPaddingEdges, 20)
        case .large:
            content
                .padding(.bottom, 2)
                .frame(maxHeight: .infinity, alignment: .center)
                .padding(horizontalPaddingEdges, 24)
        }
    }

    private var horizontalPaddingEdges: Edge.Set {
        guard let icon = config.icon else {
            return .horizontal
        }
        switch icon.alignment {
        case .leading:
            return .trailing
        case .trailing:
            return .leading
        }
    }
}

private struct IconPaddingModifier: ViewModifier {
    var config: ButtonView.Icon
    var size: ButtonView.Size

    func body(content: Content) -> some View {
        switch size {
        case .tab:
            content
                .padding(.bottom, 2)
                .frame(maxHeight: .infinity, alignment: .center)
                .padding(horizontalPaddingEdges, Layout.Tab.horizontalPadding)
        case .small:
            content
                .frame(maxHeight: .infinity, alignment: .center)
                .padding(horizontalPaddingEdges, 16)
        case .medium:
            content
                .frame(maxHeight: .infinity, alignment: .center)
                .padding(horizontalPaddingEdges, 20)
        case .large:
            content
                .frame(maxHeight: .infinity, alignment: .center)
                .padding(horizontalPaddingEdges, 24)
        }
    }

    private var horizontalPaddingEdges: Edge.Set {
        switch config.alignment {
        case .leading:
            return .leading
        case .trailing:
            return .trailing
        }
    }
}

private extension View {
    /// Shrunk text reports a shorter line box, which would pull the title up inside the
    /// top-aligned label, so the box is pinned to the unscaled line height.
    @ViewBuilder
    func shrinkToFit(minimumScaleFactor: CGFloat?, lineHeight: CGFloat) -> some View {
        if let minimumScaleFactor {
            lineLimit(1)
                .minimumScaleFactor(minimumScaleFactor)
                .frame(minHeight: lineHeight)
        } else {
            self
        }
    }

    func iconPadding(config: ButtonView.Icon, size: ButtonView.Size) -> some View {
        modifier(IconPaddingModifier(config: config, size: size))
    }

    func titlePadding(config: ButtonView.Config) -> some View {
        modifier(TitlePaddingModifier(config: config))
    }
}

private struct ButtonStateStyle: SwiftUI.ButtonStyle {
    let config: ButtonView.Config
    let cornerRadius: CGFloat
    let height: CGFloat

    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.modernButtonPreviewState) private var previewStateOverride
    @Environment(\.tkPalette) private var palette

    func makeBody(configuration: Configuration) -> some View {
        let state = state(isPressed: configuration.isPressed)

        configuration.label
            .foregroundStyle(config.appearance.textColor(for: state, palette: palette))
            .environment(\.modernButtonState, state)
            .frame(height: height)
            .background(
                RoundedRectangle(
                    cornerRadius: cornerRadius,
                    style: .continuous
                )
                .fill(config.appearance.backgroundColor(for: state, palette: palette))
            )
            .contentShape(
                RoundedRectangle(
                    cornerRadius: cornerRadius,
                    style: .continuous
                )
            )
            .animation(.easeInOut(duration: 0.14), value: state)
            .tkTapAnimation(isPressed: configuration.isPressed, haptic: .light)
    }

    private func state(isPressed: Bool) -> ButtonView.State {
        if let previewStateOverride {
            return previewStateOverride
        }

        if !isEnabled {
            return .disabled
        }

        if isPressed {
            return .highlighted
        }

        return .normal
    }
}

public struct ButtonView: View {
    @Environment(\.tkPalette) private var palette
    @Environment(\.modernButtonState) private var state

    public enum Size {
        case small
        case tab
        case medium
        case large
    }

    public enum LayoutMode {
        case fill
        case intrinsic
    }

    public enum Appearance {
        case primary
        case primaryAttention
        case primaryDestructive
        case primaryGreen
        case secondary
        case secondaryOverlay
        case attention
        case tertiary
        case icon
        case overlay
        case destructive
    }

    public enum IconAlignment {
        case leading
        case trailing
    }

    public struct Icon {
        public var image: UIImage
        public var alignment: IconAlignment

        public init(
            image: UIImage,
            alignment: IconAlignment = .leading
        ) {
            self.image = image
            self.alignment = alignment
        }
    }

    public struct Config {
        public enum Title {
            case plain(String)
            case attributed(AttributedString)
        }

        public var title: Title
        public var size: Size
        public var appearance: Appearance
        public var layoutMode: LayoutMode
        public var icon: Icon?
        public var showsLoader: Bool
        public var minimumTitleScaleFactor: CGFloat?
        public var action: () -> Void

        public init(
            title: String,
            size: Size,
            layoutMode: LayoutMode = .intrinsic,
            appearance: Appearance,
            icon: Icon? = nil,
            showsLoader: Bool = false,
            minimumTitleScaleFactor: CGFloat? = nil,
            action: @escaping () -> Void
        ) {
            self.title = .plain(title)
            self.size = size
            self.appearance = appearance
            self.layoutMode = layoutMode
            self.icon = icon
            self.showsLoader = showsLoader
            self.minimumTitleScaleFactor = minimumTitleScaleFactor
            self.action = action
        }

        public init(
            title: AttributedString,
            size: Size,
            layoutMode: LayoutMode = .intrinsic,
            appearance: Appearance,
            icon: Icon? = nil,
            showsLoader: Bool = false,
            minimumTitleScaleFactor: CGFloat? = nil,
            action: @escaping () -> Void
        ) {
            self.title = .attributed(title)
            self.size = size
            self.appearance = appearance
            self.layoutMode = layoutMode
            self.icon = icon
            self.showsLoader = showsLoader
            self.minimumTitleScaleFactor = minimumTitleScaleFactor
            self.action = action
        }
    }

    enum State: Equatable {
        case normal
        case highlighted
        case disabled
    }

    public var config: Config

    public init(config: Config) {
        self.config = config
    }

    public var body: some View {
        SwiftUI.Button(action: config.action) {
            switch config.layoutMode {
            case .fill:
                content
                    .frame(maxWidth: .infinity)
            case .intrinsic:
                content
            }
        }
        .buttonStyle(
            ButtonStateStyle(
                config: config,
                cornerRadius: cornerRadius,
                height: height
            )
        )
        .allowsHitTesting(!config.showsLoader)
    }

    @ViewBuilder
    private var content: some View {
        if config.showsLoader {
            loaderView
        } else {
            HStack(spacing: 8) {
                if let icon = config.icon {
                    switch icon.alignment {
                    case .leading:
                        iconView(icon)
                        titleView
                    case .trailing:
                        titleView
                        iconView(icon)
                    }
                } else {
                    titleView
                }
            }
        }
    }

    private var loaderView: some View {
        CircularLoader(
            mode: .indeterminate,
            preset: .custom(
                CircularLoaderConfiguration(
                    lineWidth: 2,
                    progressColor: config.appearance.textColor(for: .normal, palette: palette),
                    trackColor: config.appearance.textColor(for: .normal, palette: palette).opacity(0.32),
                    size: CGSize(width: loaderSize, height: loaderSize),
                    contentPadding: 1
                )
            )
        )
        .frame(width: loaderSize, height: loaderSize)
        .titlePadding(config: config)
    }

    private var loaderSize: CGFloat {
        switch config.size {
        case .tab, .small:
            16
        case .medium, .large:
            20
        }
    }

    private func iconView(_ icon: Icon) -> some View {
        Image(uiImage: icon.image)
            .renderingMode(.template)
            .resizable()
            .scaledToFit()
            .foregroundStyle(
                config.appearance.iconColor(for: state, palette: palette)
            )
            .frame(width: iconSize, height: iconSize)
            .iconPadding(config: icon, size: config.size)
    }

    private var titleView: some View {
        Group {
            switch config.title {
            case let .plain(title):
                Text(title)
                    .textStyle(textStyle)
            case let .attributed(title):
                Text(title)
                    .textStyle(textStyle)
            }
        }
        .shrinkToFit(
            minimumScaleFactor: config.minimumTitleScaleFactor,
            lineHeight: textStyle.lineHeight
        )
        .titlePadding(config: config)
    }

    private var iconSize: CGFloat {
        switch config.size {
        case .tab, .small, .medium, .large:
            16
        }
    }

    private var textStyle: TKTextStyle {
        switch config.size {
        case .large, .medium:
            .label1
        case .tab, .small:
            .label2
        }
    }

    private var cornerRadius: CGFloat {
        switch config.size {
        case .tab:
            Layout.Tab.cornerRadius
        case .small:
            18
        case .medium:
            24
        case .large:
            16
        }
    }

    private var height: CGFloat {
        switch config.size {
        case .tab:
            Layout.Tab.height
        case .small:
            36
        case .medium:
            48
        case .large:
            56
        }
    }
}

private enum Layout {
    enum Tab {
        static let titleTopPadding: CGFloat = 6
        static let iconTopPadding: CGFloat = 7
        static let horizontalPadding: CGFloat = 12
        static let cornerRadius: CGFloat = 16
        static let height: CGFloat = 32
    }
}

extension ButtonView.Appearance {
    func textColor(for state: ButtonView.State, palette: TKPalette) -> Color {
        switch state {
        case .normal:
            normalTextColor(palette)
        case .highlighted:
            highlightedTextColor(palette)
        case .disabled:
            disabledTextColor(palette)
        }
    }

    func iconColor(for state: ButtonView.State, palette: TKPalette) -> Color {
        guard self == .tertiary || self == .icon else {
            return textColor(for: state, palette: palette)
        }

        switch state {
        case .normal, .highlighted:
            if self == .tertiary {
                return palette.icon.secondary
            }
            return palette.button.tertiaryForeground
        case .disabled:
            if self == .tertiary {
                return palette.icon.secondary.opacity(0.48)
            }
            return palette.button.tertiaryForeground.opacity(0.48)
        }
    }

    func backgroundColor(for state: ButtonView.State, palette: TKPalette) -> Color {
        switch state {
        case .normal:
            normalBackgroundColor(palette)
        case .highlighted:
            highlightedBackgroundColor(palette)
        case .disabled:
            disabledBackgroundColor(palette)
        }
    }

    private func normalTextColor(_ palette: TKPalette) -> Color {
        switch self {
        case .primary:
            palette.button.primaryForeground
        case .primaryAttention, .primaryDestructive, .primaryGreen:
            palette.button.primaryForeground
        case .secondary, .secondaryOverlay:
            palette.button.secondaryForeground
        case .attention:
            palette.accent.orange
        case .tertiary:
            palette.button.tertiaryForeground
        case .icon:
            palette.text.secondary
        case .overlay:
            palette.constant.black
        case .destructive:
            palette.accent.red
        }
    }

    private func normalBackgroundColor(_ palette: TKPalette) -> Color {
        switch self {
        case .primary:
            palette.button.primaryBackground
        case .primaryAttention:
            palette.accent.orange
        case .primaryDestructive:
            palette.accent.red
        case .primaryGreen:
            palette.button.primaryBackgroundGreen
        case .secondary:
            palette.button.secondaryBackground
        case .secondaryOverlay:
            .clear
        case .attention:
            palette.accent.orange.opacity(0.08)
        case .tertiary:
            palette.button.tertiaryBackground
        case .icon:
            palette.button.secondaryBackground
        case .overlay:
            palette.constant.white
        case .destructive:
            palette.accent.red.opacity(0.08)
        }
    }

    private func highlightedTextColor(_ palette: TKPalette) -> Color {
        switch self {
        case .primary, .primaryAttention, .primaryDestructive, .primaryGreen,
             .secondary, .secondaryOverlay, .attention,
             .tertiary, .icon, .overlay, .destructive:
            normalTextColor(palette)
        }
    }

    private func highlightedBackgroundColor(_ palette: TKPalette) -> Color {
        switch self {
        case .primary:
            palette.button.primaryBackgroundHighlighted
        case .primaryAttention:
            palette.accent.orange.opacity(0.84)
        case .primaryDestructive:
            palette.accent.red.opacity(0.84)
        case .primaryGreen:
            palette.button.primaryBackgroundGreenHighlighted
        case .secondary:
            palette.button.secondaryBackgroundHighlighted
        case .secondaryOverlay:
            .clear
        case .attention:
            palette.accent.orange.opacity(0.12)
        case .tertiary:
            palette.button.tertiaryBackgroundHighlighted
        case .icon:
            palette.button.secondaryBackgroundHighlighted
        case .overlay:
            palette.constant.white
        case .destructive:
            palette.accent.red.opacity(0.12)
        }
    }

    private func disabledTextColor(_ palette: TKPalette) -> Color {
        switch self {
        case .primary, .primaryAttention, .primaryDestructive, .primaryGreen,
             .secondary, .secondaryOverlay, .attention,
             .tertiary, .icon, .overlay, .destructive:
            normalTextColor(palette).opacity(0.48)
        }
    }

    private func disabledBackgroundColor(_ palette: TKPalette) -> Color {
        switch self {
        case .primary:
            palette.button.primaryBackgroundDisabled
        case .primaryAttention:
            palette.accent.orange.opacity(0.48)
        case .primaryDestructive:
            palette.accent.red.opacity(0.48)
        case .primaryGreen:
            palette.button.primaryBackgroundGreenDisabled
        case .secondary:
            palette.button.secondaryBackgroundDisabled
        case .secondaryOverlay:
            .clear
        case .attention:
            palette.accent.orange.opacity(0.04)
        case .tertiary:
            palette.button.tertiaryBackgroundDisabled
        case .icon:
            palette.button.secondaryBackgroundDisabled
        case .overlay:
            palette.constant.white
        case .destructive:
            palette.accent.red.opacity(0.04)
        }
    }
}
