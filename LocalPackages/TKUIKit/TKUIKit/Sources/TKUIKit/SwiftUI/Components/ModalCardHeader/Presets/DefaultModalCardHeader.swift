import Lottie
import SwiftUI

public struct DefaultModalCardHeader: View {
    var config: Config

    @Environment(\.tkPalette) private var palette
    @Environment(\.tkPreviewLiquidGlass) private var previewLiquidGlass
    @Environment(\.tkModalCardHeaderStaysInCard) private var staysInCard

    @State private var rightButtonAnchorView: UIView?
    @State private var secondaryRightButtonAnchorView: UIView?
    @State private var leftButtonAnchorView: UIView?
    /// Under liquid glass a header in a navigation controller hands its content to the system bar.
    @State private var isInNavigationStack = false

    private let usesSystemBar = TKLiquidGlass.isEnabled

    public init(config: Config) {
        self.config = config
    }

    public var body: some View {
        if #available(iOS 26.0, *), usesSystemBar, !staysInCard {
            systemBarBody
        } else {
            cardBody
        }
    }

    private var cardBody: some View {
        Group {
            switch config.height {
            case .compact:
                content
            case let .atLeast(minHeight):
                content
                    .frame(minHeight: minHeight)
            }
        }
        .frame(maxWidth: .infinity)
        .fixedSize(horizontal: false, vertical: true)
        .background(backgroundView)
    }

    @ViewBuilder
    private var backgroundView: some View {
        switch config.background {
        case .solid:
            TKColor.backgroundPage
        case .scrim:
            TKColor.clear
                .tkScrim(.backgroundPage, edge: .top)
        }
    }

    private var content: some View {
        VStack(spacing: 0) {
            ModalCardHeader(
                config: ModalCardHeader.Config(
                    headerContentAlignment: config.title.alignment
                )
            ) {
                if let icon = config.leftIcon {
                    iconButton(config: icon, anchor: $leftButtonAnchorView)
                }
            } center: {
                if let subtitle = config.subtitle {
                    VStack(spacing: 0) {
                        titleView
                            .padding(.top, metrics.titleTopPaddingCompact)
                        if let onTap = subtitle.onTap {
                            Button {
                                onTap()
                            } label: {
                                subtitleView(subtitle: subtitle)
                            }
                            .buttonStyle(TKTapAnimationButtonStyle(haptic: .light))
                        } else {
                            subtitleView(subtitle: subtitle)
                        }
                        Spacer(minLength: 0)
                    }
                } else {
                    titleView
                        .padding(.top, metrics.titleTopPaddingRegular)
                        .padding(.bottom, titleBottomPadding)
                }
            } trailing: {
                HStack(spacing: metrics.trailingButtonsSpacing) {
                    if let icon = config.rightIcon {
                        iconButton(config: icon, anchor: $rightButtonAnchorView)
                    }
                    if let icon = config.secondaryRightIcon {
                        iconButton(config: icon, anchor: $secondaryRightButtonAnchorView)
                    }
                    if let rightTextButton = config.rightTextButton {
                        textButton(config: rightTextButton)
                    }
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, metrics.horizontalInset)
    }

    private var isGlass: Bool {
        TKLiquidGlass.isEnabled(previewPin: previewLiquidGlass)
    }

    private var metrics: Layout.Metrics {
        isGlass ? .liquidGlass : .regular
    }

    /// A compact header is as tall as its content, so space below the title would move what follows it.
    private var titleBottomPadding: CGFloat {
        guard case .atLeast = config.height else { return 0 }
        return metrics.titleBottomPadding
    }

    private var glassTint: Color {
        palette.background.content.opacity(Layout.LiquidGlass.tintOpacity)
    }

    private var titleView: some View {
        Group {
            if let trailingIcon = config.title.trailingIcon {
                HStack(spacing: Layout.titleTrailingIconSpacing) {
                    titleText
                    Button(action: trailingIcon.onTap) {
                        Image(uiImage: trailingIcon.image)
                            .resizable()
                            .scaledToFit()
                            .foregroundStyle(trailingIcon.tint)
                            .frame(width: trailingIcon.size, height: trailingIcon.size)
                    }
                    .buttonStyle(TKTapAnimationButtonStyle(haptic: .light))
                }
            } else {
                titleText
            }
        }
        .frame(maxWidth: .infinity, alignment: config.title.alignment.swiftUiAlignment)
        // A title at a side lines up with the buttons' glass, not with their slots.
        .padding(.horizontal, isGlass && config.title.alignment != .center ? Layout.LiquidGlass.buttonInset : 0)
    }

    private var titleText: some View {
        Text(config.title.text)
            .textStyle(.h3)
            .foregroundStyle(.textPrimary)
            .multilineTextAlignment(config.title.alignment.textAlignment)
            .fixedSize(horizontal: false, vertical: true)
    }

    private func subtitleView(subtitle: Subtitle) -> some View {
        VStack(spacing: 0) {
            HStack(alignment: .top, spacing: Layout.subtitleElementsPadding) {
                Spacer(minLength: 0)
                HStack(alignment: subtitle.accentImageURL == nil ? .firstTextBaseline : .center, spacing: 0) {
                    Text(subtitle.text)
                        .textStyle(.body2)
                        .foregroundStyle(subtitle.color)
                    if let url = subtitle.accentImageURL {
                        AssetAvatarView(
                            imageSource: .url(url),
                            configuration: AssetAvatarView.Configuration(
                                imageSize: Layout.subtitleAccentImageSize,
                                chainIconSize: 0,
                                chainIconPadding: 0,
                                chainIconOffsetX: 0,
                                chainIconOffsetY: 0
                            ),
                            shape: .circle
                        )
                        .padding(.leading, Layout.subtitleAccentImageLeading)
                    }
                    if let accentText = subtitle.accentText, !accentText.isEmpty {
                        Text(subtitle.accentImageURL == nil ? " \(accentText)" : accentText)
                            .textStyle(.body2)
                            .foregroundStyle(subtitle.accentColor)
                            .padding(.leading, subtitle.accentImageURL == nil ? 0 : Layout.subtitleAccentImageTrailing)
                    }
                }
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                if let icon = subtitle.icon {
                    Image(uiImage: icon.image)
                        .resizable()
                        .scaledToFit()
                        .foregroundStyle(subtitleIconColor(subtitle))
                        .frame(width: icon.size, height: icon.size)
                        .padding(.top, icon.topPadding)
                }
                Spacer(minLength: 0)
            }
            Spacer(minLength: 0)
        }
    }

    private func subtitleIconColor(_ subtitle: Subtitle) -> TKColor {
        if subtitle.accentText != nil {
            return subtitle.accentColor
        }
        return subtitle.color
    }

    private func iconButton(
        config: Icon,
        anchor: Binding<UIView?>
    ) -> some View {
        Button {
            config.onTap(anchor.wrappedValue)
        } label: {
            iconView(config: config)
        }
        .buttonStyle(TKTapAnimationButtonStyle(haptic: .light))
        .accessibilityIdentifierIfPresent(config.accessibilityIdentifier)
        .padding(.top, metrics.buttonsTopPadding)
        .overlay(
            AnchorViewResolver { view in
                anchor.wrappedValue = view
                config.onResolveAnchorView?(view)
            }
        )
    }

    private func textButton(config: TextButton) -> some View {
        Button(action: config.onTap) {
            if isGlass {
                Text(config.title)
                    .textStyle(.label2)
                    .foregroundStyle(.buttonSecondaryForeground)
                    .padding(.horizontal, Layout.LiquidGlass.textButtonHorizontalPadding)
                    .frame(height: Layout.LiquidGlass.buttonSide)
                    .tkGlassBackground(tint: glassTint, in: Capsule())
                    .padding(Layout.LiquidGlass.buttonInset)
            } else {
                Text(config.title)
                    .textStyle(.label2)
                    .foregroundStyle(.buttonSecondaryForeground)
                    .padding(.horizontal, Layout.textButtonHorizontalPadding)
                    .frame(height: Layout.textButtonHeight)
                    .background(.buttonSecondaryBackground)
                    .clipShape(Capsule())
            }
        }
        .buttonStyle(TKTapAnimationButtonStyle(haptic: .light))
        .accessibilityIdentifierIfPresent(config.accessibilityIdentifier)
        .padding(.top, metrics.buttonsTopPadding)
    }

    @ViewBuilder
    private func iconView(
        config: Icon
    ) -> some View {
        if isGlass {
            iconContent(
                config: config,
                image: config.liquidGlassImage ?? config.image,
                size: config.liquidGlassImage == nil ? config.size : Layout.LiquidGlass.iconSide
            )
            .frame(width: Layout.LiquidGlass.buttonSide, height: Layout.LiquidGlass.buttonSide)
            // A lottie drawn at the glass glyph size spreads its ripple past the circle.
            .clipShape(Circle())
            // The glass takes no touches, and neither does a lottie: the circle is the button.
            .contentShape(Circle())
            .tkGlassBackground(tint: glassTint, in: Circle())
            .padding(Layout.LiquidGlass.buttonInset)
        } else {
            iconContent(config: config, image: config.image, size: config.size)
                .padding(config.lottie == nil ? config.padding : 0)
                .background(.buttonSecondaryBackground)
                .clipShape(Circle())
        }
    }

    @ViewBuilder
    private func iconContent(config: Icon, image: UIImage, size: CGFloat) -> some View {
        if let lottie = config.lottie {
            if isGlass {
                // The animation draws its glyph at `config.size` inside `config.padding`, so it scales with the glyph.
                let glyphScale = config.size > 0 ? size / config.size : 1
                LottieFramesIconView(
                    resource: lottie.resource,
                    isOn: lottie.isOn,
                    side: Layout.LiquidGlass.buttonSide,
                    contentSide: (config.size + config.padding * 2) * glyphScale
                )
            } else {
                LottieIconView(resource: lottie.resource, isOn: lottie.isOn)
                    .frame(
                        width: config.size + config.padding * 2,
                        height: config.size + config.padding * 2
                    )
            }
        } else {
            Image(uiImage: image)
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .frame(width: size, height: size)
                .foregroundStyle(config.tintColor)
        }
    }
}

@available(iOS 26.0, *)
private extension DefaultModalCardHeader {
    /// Away from a navigation controller there is no system bar, so the card header stays.
    var systemBarBody: some View {
        Group {
            if isInNavigationStack {
                Color.clear.frame(height: 0)
            } else {
                cardBody
            }
        }
        .background(
            TKNavigationStackProbe { isInStack in
                guard isInNavigationStack != isInStack else { return }
                isInNavigationStack = isInStack
            }
        )
        .toolbar {
            if isInNavigationStack {
                systemBarToolbar
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        // The bridged toolbar owns the navigation item, so the hosting controller's own flag is not enough;
        // the header's back button, if any, is its left icon.
        .navigationBarBackButtonHidden(isInNavigationStack)
    }

    @ToolbarContentBuilder
    var systemBarToolbar: some ToolbarContent {
        if let icon = config.leftIcon {
            ToolbarItem(placement: .topBarLeading) {
                systemBarIconButton(icon, anchor: $leftButtonAnchorView)
            }
        }
        if hasSystemBarTitle {
            ToolbarItem(placement: .principal) {
                systemBarTitle
            }
        }
        if let icon = config.rightIcon {
            ToolbarItem(placement: .topBarTrailing) {
                systemBarIconButton(icon, anchor: $rightButtonAnchorView)
            }
        }
        if let icon = config.secondaryRightIcon {
            // Keeps the two buttons in separate glass circles.
            ToolbarSpacer(.fixed, placement: .topBarTrailing)
            ToolbarItem(placement: .topBarTrailing) {
                systemBarIconButton(icon, anchor: $secondaryRightButtonAnchorView)
            }
        }
        if let textButton = config.rightTextButton {
            ToolbarItem(placement: .topBarTrailing) {
                Button(action: textButton.onTap) {
                    Text(textButton.title)
                        .textStyle(.label2)
                        .foregroundStyle(.buttonSecondaryForeground)
                }
                .accessibilityIdentifierIfPresent(textButton.accessibilityIdentifier)
            }
        }
    }

    func systemBarIconTint(_ icon: Icon) -> TKColor {
        if icon.lottie?.isOn == true {
            return .accentBlue
        }
        return icon.tintColor == .buttonSecondaryForeground ? .iconPrimary : icon.tintColor
    }

    var hasSystemBarTitle: Bool {
        !config.title.text.isEmpty || config.subtitle != nil
    }

    var systemBarTitle: some View {
        VStack(spacing: 0) {
            if !config.title.text.isEmpty {
                titleView
            }
            if let subtitle = config.subtitle {
                if let onTap = subtitle.onTap {
                    Button(action: onTap) {
                        subtitleView(subtitle: subtitle)
                    }
                    .buttonStyle(TKTapAnimationButtonStyle(haptic: .light))
                } else {
                    subtitleView(subtitle: subtitle)
                }
            }
        }
        .fixedSize()
    }

    func systemBarIconButton(_ icon: Icon, anchor: Binding<UIView?>) -> some View {
        Button {
            icon.onTap(anchor.wrappedValue)
        } label: {
            // A Lottie icon is drawn for a 16 pt glyph, so the bar shows its static glyph at the bar's size,
            // in the accent colour while it is on.
            let liquidGlassImage = icon.liquidGlassImage
            Image(uiImage: liquidGlassImage ?? icon.image)
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .frame(
                    width: liquidGlassImage == nil ? icon.size : icon.systemBarImageSize,
                    height: liquidGlassImage == nil ? icon.size : icon.systemBarImageSize
                )
                .foregroundStyle(systemBarIconTint(icon))
        }
        .accessibilityIdentifierIfPresent(icon.accessibilityIdentifier)
        .overlay(
            AnchorViewResolver { view in
                anchor.wrappedValue = view
                icon.onResolveAnchorView?(view)
            }
        )
    }
}

private struct LottieIconView: View {
    let resource: LottieResource
    let isOn: Bool

    @State private var playbackMode: LottiePlaybackMode

    init(resource: LottieResource, isOn: Bool) {
        self.resource = resource
        self.isOn = isOn
        _playbackMode = State(initialValue: .paused(at: .progress(isOn ? 1 : 0)))
    }

    var body: some View {
        LottieView(
            animation: LottieAnimation.named(
                resource.name,
                bundle: resource.bundle,
                subdirectory: resource.subdirectory
            )
        )
        .resizable()
        .playbackMode(playbackMode)
        .configure { $0.backgroundBehavior = .pauseAndRestore }
        .allowsHitTesting(false)
        .onChange(of: isOn) { newValue in
            playbackMode = newValue
                ? .playing(.fromProgress(nil, toProgress: 1, loopMode: .playOnce))
                : .paused(at: .progress(0))
        }
    }
}

/// Plays the animation as images, as the tab bar does: glass glitches over a live animation view.
private struct LottieFramesIconView: View {
    let resource: LottieResource
    let isOn: Bool
    let side: CGFloat
    let contentSide: CGFloat

    @Environment(\.displayScale) private var displayScale
    @State private var playbackStart: Date?

    var body: some View {
        // Ready on first draw, which draws one frame: no empty circle, and a tap finds its playback.
        let frames = TKLottieFrames.frames(
            resource,
            size: CGSize(width: side, height: side),
            contentSize: CGSize(width: contentSide, height: contentSide),
            scale: displayScale,
            colors: .original
        )
        TimelineView(.animation(minimumInterval: nil, paused: playbackStart == nil)) { context in
            if let frames {
                Image(uiImage: frames.image(at: frameIndex(at: context.date, of: frames)))
                    .resizable()
            }
        }
        .frame(width: side, height: side)
        .allowsHitTesting(false)
        .task(id: playbackStart) {
            guard let playbackStart else { return }
            let remaining = (frames?.duration ?? 0) - Date().timeIntervalSince(playbackStart)
            if remaining > 0 {
                try? await Task.sleep(nanoseconds: UInt64(remaining * 1_000_000_000))
            }
            guard !Task.isCancelled else { return }
            self.playbackStart = nil
        }
        .onChange(of: isOn) { newValue in
            playbackStart = newValue ? Date() : nil
        }
    }

    private func frameIndex(at date: Date, of frames: TKLottieFrames) -> Int {
        guard let playbackStart else { return isOn ? frames.count - 1 : 0 }
        return Int(date.timeIntervalSince(playbackStart) * frames.framerate)
    }
}

public extension DefaultModalCardHeader {
    enum Height {
        case compact
        case atLeast(CGFloat)
    }

    enum Background {
        case solid
        case scrim
    }

    struct Lottie {
        public var resource: LottieResource
        public var isOn: Bool

        public init(resource: LottieResource, isOn: Bool) {
            self.resource = resource
            self.isOn = isOn
        }
    }

    struct Icon {
        public var image: UIImage
        public var size: CGFloat
        public var padding: CGFloat
        public var accessibilityIdentifier: String?
        public var tintColor: TKColor
        public var lottie: Lottie?
        public var onTap: (_ sourceView: UIView?) -> Void
        public var onResolveAnchorView: ((UIView) -> Void)?
        /// Drawn at 28 pt on liquid glass, as the design system's header buttons are; without it the glass
        /// button keeps `image` at `size`.
        public var liquidGlassImage: UIImage?
        /// The system bar's size for `liquidGlassImage`, for a glyph that fills its 28 pt canvas more than the
        /// outline icons do, so it looks as heavy as them.
        public var systemBarImageSize: CGFloat

        public init(
            image: UIImage,
            size: CGFloat,
            padding: CGFloat,
            accessibilityIdentifier: String? = nil,
            tintColor: TKColor = .buttonSecondaryForeground,
            lottie: Lottie? = nil,
            liquidGlassImage: UIImage? = nil,
            systemBarImageSize: CGFloat = 28,
            onTap: @escaping (_ sourceView: UIView?) -> Void,
            onResolveAnchorView: ((UIView) -> Void)? = nil
        ) {
            self.image = image
            self.size = size
            self.padding = padding
            self.accessibilityIdentifier = accessibilityIdentifier
            self.tintColor = tintColor
            self.lottie = lottie
            self.liquidGlassImage = liquidGlassImage
            self.onTap = onTap
            self.onResolveAnchorView = onResolveAnchorView
            self.systemBarImageSize = systemBarImageSize
        }

        public static func close(
            accessibilityIdentifier: String? = nil,
            onTap: @escaping (_ sourceView: UIView?) -> Void = { _ in }
        ) -> Icon {
            Icon(
                image: .TKUIKit.Icons.Size16.close,
                size: 16,
                padding: 8,
                accessibilityIdentifier: accessibilityIdentifier,
                liquidGlassImage: .TKUIKit.Icons.Size28.xmarkOutline,
                onTap: onTap
            )
        }

        public static func back(
            accessibilityIdentifier: String? = nil,
            onTap: @escaping (_ sourceView: UIView?) -> Void = { _ in }
        ) -> Icon {
            Icon(
                image: .TKUIKit.Icons.Size16.chevronLeft,
                size: 16,
                padding: 8,
                accessibilityIdentifier: accessibilityIdentifier,
                liquidGlassImage: .TKUIKit.Icons.Size28.chevronLeft,
                onTap: onTap
            )
        }
    }

    struct TextButton {
        public var title: String
        public var accessibilityIdentifier: String?
        public var onTap: () -> Void

        public init(
            title: String,
            accessibilityIdentifier: String? = nil,
            onTap: @escaping () -> Void
        ) {
            self.title = title
            self.accessibilityIdentifier = accessibilityIdentifier
            self.onTap = onTap
        }
    }

    struct Title {
        public var text: String
        public var alignment: ModalCardHeaderContentAlignment
        public var trailingIcon: TitleTrailingIcon?

        public init(
            text: String,
            alignment: ModalCardHeaderContentAlignment = .center,
            trailingIcon: TitleTrailingIcon? = nil
        ) {
            self.text = text
            self.alignment = alignment
            self.trailingIcon = trailingIcon
        }

        public static var empty: Title {
            Title(text: "")
        }
    }

    struct TitleTrailingIcon {
        public var image: UIImage
        public var tint: TKColor
        public var size: CGFloat
        public var onTap: () -> Void

        public init(
            image: UIImage,
            tint: TKColor,
            size: CGFloat,
            onTap: @escaping () -> Void
        ) {
            self.image = image
            self.tint = tint
            self.size = size
            self.onTap = onTap
        }
    }

    struct SubtitleIcon {
        public var image: UIImage
        public var size: CGFloat
        public var topPadding: CGFloat

        public init(image: UIImage, size: CGFloat, topPadding: CGFloat) {
            self.image = image
            self.size = size
            self.topPadding = topPadding
        }
    }

    struct Subtitle {
        public var text: String
        public var color: TKColor
        public var accentText: String?
        public var accentColor: TKColor
        public var accentImageURL: URL?
        public var icon: SubtitleIcon?
        public var onTap: (() -> Void)?

        public init(
            text: String,
            color: TKColor = .textSecondary,
            accentText: String? = nil,
            accentColor: TKColor = .accentBlue,
            accentImageURL: URL? = nil,
            icon: SubtitleIcon? = nil,
            onTap: (() -> Void)? = nil
        ) {
            self.text = text
            self.color = color
            self.accentText = accentText
            self.accentColor = accentColor
            self.accentImageURL = accentImageURL
            self.icon = icon
            self.onTap = onTap
        }
    }

    struct Config {
        public var leftIcon: Icon?
        public var title: Title
        public var subtitle: Subtitle?
        public var rightIcon: Icon?
        public var secondaryRightIcon: Icon?
        public var rightTextButton: TextButton?
        public var height: Height
        public var background: Background

        public init(
            leftIcon: Icon? = nil,
            title: Title = .empty,
            subtitle: Subtitle? = nil,
            rightIcon: Icon? = nil,
            secondaryRightIcon: Icon? = nil,
            rightTextButton: TextButton? = nil,
            height: Height? = nil,
            background: Background = .solid
        ) {
            self.leftIcon = leftIcon
            self.title = title
            self.subtitle = subtitle
            self.rightIcon = rightIcon
            self.secondaryRightIcon = secondaryRightIcon
            self.rightTextButton = rightTextButton
            self.height = height ?? .atLeast(Layout.minHeight)
            self.background = background
        }

        public static func push(
            title: String,
            backAccessibilityIdentifier: String? = nil,
            onBack: @escaping () -> Void
        ) -> Config {
            Config(
                leftIcon: .back(accessibilityIdentifier: backAccessibilityIdentifier) { _ in onBack() },
                title: Title(text: title)
            )
        }
    }
}

extension DefaultModalCardHeader {
    enum Layout {
        static let subtitleElementsPadding: CGFloat = 4
        static let subtitleAccentImageSize: CGFloat = 12
        static let subtitleAccentImageLeading: CGFloat = 4
        static let subtitleAccentImageTrailing: CGFloat = 4
        static let titleTrailingIconSpacing: CGFloat = 4

        static let textButtonHeight: CGFloat = 32
        static let textButtonHorizontalPadding: CGFloat = 12
        static let minHeight: CGFloat = 64

        /// The title is centred on the buttons' row in both variants. The glass row keeps the header at the
        /// 64 pt its callers lay content under (Figma's 70 has 8 pt below the buttons, this has 2). In a header
        /// with a minimum height, a glass title that wraps past it keeps Figma's 8 pt below; one line still fits.
        struct Metrics {
            var horizontalInset: CGFloat
            var buttonsTopPadding: CGFloat
            var titleTopPaddingRegular: CGFloat
            var titleTopPaddingCompact: CGFloat
            var titleBottomPadding: CGFloat
            var trailingButtonsSpacing: CGFloat

            static let regular = Metrics(
                horizontalInset: 16,
                buttonsTopPadding: 16,
                titleTopPaddingRegular: 18,
                titleTopPaddingCompact: 8,
                titleBottomPadding: 0,
                trailingButtonsSpacing: 12
            )

            static let liquidGlass = Metrics(
                horizontalInset: 14,
                buttonsTopPadding: 14,
                titleTopPaddingRegular: 24,
                titleTopPaddingCompact: 14,
                titleBottomPadding: 8,
                trailingButtonsSpacing: 8
            )
        }

        enum LiquidGlass {
            static let buttonSide: CGFloat = 44
            static let iconSide: CGFloat = 28
            /// A button's glass sits inside a 48 pt slot.
            static let buttonInset: CGFloat = 2
            static let textButtonHorizontalPadding: CGFloat = 16
            static let tintOpacity: CGFloat = 0.8
        }
    }
}

private extension View {
    @ViewBuilder
    func accessibilityIdentifierIfPresent(_ identifier: String?) -> some View {
        if let identifier {
            accessibilityIdentifier(identifier)
        } else {
            self
        }
    }
}

private struct TKModalCardHeaderStaysInCardKey: EnvironmentKey {
    static let defaultValue = false
}

public extension EnvironmentValues {
    var tkModalCardHeaderStaysInCard: Bool {
        get { self[TKModalCardHeaderStaysInCardKey.self] }
        set { self[TKModalCardHeaderStaysInCardKey.self] = newValue }
    }
}

public extension View {
    /// Keeps `DefaultModalCardHeader`s drawn as cards in a navigation stack under liquid glass, for a screen
    /// that shows headers as content rather than as its own header, such as a catalog of them.
    func tkModalCardHeaderStaysInCard() -> some View {
        environment(\.tkModalCardHeaderStaysInCard, true)
    }
}
