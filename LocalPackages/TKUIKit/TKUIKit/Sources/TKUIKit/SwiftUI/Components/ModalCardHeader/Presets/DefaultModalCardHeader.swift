import Lottie
import SwiftUI

public struct DefaultModalCardHeader: View {
    var config: Config

    @State private var rightButtonAnchorView: UIView?
    @State private var secondaryRightButtonAnchorView: UIView?
    @State private var leftButtonAnchorView: UIView?

    public init(config: Config) {
        self.config = config
    }

    public var body: some View {
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
                            .padding(.top, Layout.titleTopPaddingCompact)
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
                        .padding(.top, Layout.titleTopPaddingRegular)
                }
            } trailing: {
                HStack(spacing: Layout.trailingIconsSpacing) {
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
        .padding(.horizontal, Layout.horizontalInset)
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
                HStack(alignment: .firstTextBaseline, spacing: 0) {
                    Text(subtitle.text)
                        .textStyle(.body2)
                        .foregroundStyle(subtitle.color)
                    if let accentText = subtitle.accentText, !accentText.isEmpty {
                        Text(" \(accentText)")
                            .textStyle(.body2)
                            .foregroundStyle(subtitle.accentColor)
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
        .padding(.top, Layout.iconTopPadding)
        .overlay(
            AnchorViewResolver { view in
                anchor.wrappedValue = view
                config.onResolveAnchorView?(view)
            }
        )
    }

    private func textButton(config: TextButton) -> some View {
        Button(action: config.onTap) {
            Text(config.title)
                .textStyle(.label2)
                .foregroundStyle(.buttonSecondaryForeground)
                .padding(.horizontal, Layout.textButtonHorizontalPadding)
                .frame(height: Layout.textButtonHeight)
                .background(.buttonSecondaryBackground)
                .clipShape(Capsule())
        }
        .buttonStyle(TKTapAnimationButtonStyle(haptic: .light))
        .accessibilityIdentifierIfPresent(config.accessibilityIdentifier)
        .padding(.top, Layout.iconTopPadding)
    }

    private func iconView(
        config: Icon
    ) -> some View {
        Group {
            if let lottie = config.lottie {
                LottieIconView(resource: lottie.resource, isOn: lottie.isOn)
                    .frame(
                        width: config.size + config.padding * 2,
                        height: config.size + config.padding * 2
                    )
            } else {
                Image(uiImage: config.image)
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
                    .frame(
                        width: config.size,
                        height: config.size
                    )
                    .foregroundStyle(config.tintColor)
                    .padding(config.padding)
            }
        }
        .background(.buttonSecondaryBackground)
        .clipShape(Circle())
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

        public init(
            image: UIImage,
            size: CGFloat,
            padding: CGFloat,
            accessibilityIdentifier: String? = nil,
            tintColor: TKColor = .buttonSecondaryForeground,
            lottie: Lottie? = nil,
            onTap: @escaping (_ sourceView: UIView?) -> Void,
            onResolveAnchorView: ((UIView) -> Void)? = nil
        ) {
            self.image = image
            self.size = size
            self.padding = padding
            self.accessibilityIdentifier = accessibilityIdentifier
            self.tintColor = tintColor
            self.lottie = lottie
            self.onTap = onTap
            self.onResolveAnchorView = onResolveAnchorView
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
        public var icon: SubtitleIcon?
        public var onTap: (() -> Void)?

        public init(
            text: String,
            color: TKColor = .textSecondary,
            accentText: String? = nil,
            accentColor: TKColor = .accentBlue,
            icon: SubtitleIcon? = nil,
            onTap: (() -> Void)? = nil
        ) {
            self.text = text
            self.color = color
            self.accentText = accentText
            self.accentColor = accentColor
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
        static let horizontalInset: CGFloat = 16
        static let titleTopPaddingRegular: CGFloat = 18
        static let titleTopPaddingCompact: CGFloat = 8
        static let subtitleElementsPadding: CGFloat = 4
        static let titleTrailingIconSpacing: CGFloat = 4

        static let iconTopPadding: CGFloat = 16
        static let trailingIconsSpacing: CGFloat = 12
        static let textButtonHeight: CGFloat = 32
        static let textButtonHorizontalPadding: CGFloat = 12
        static let minHeight: CGFloat = 64
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
