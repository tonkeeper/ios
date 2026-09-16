import Lottie
import SwiftUI

public struct PlaceholderView: View {
    public struct ButtonConfig {
        public var title: String
        public var icon: UIImage?
        public var action: () -> Void

        public init(
            title: String,
            icon: UIImage? = nil,
            action: @escaping () -> Void
        ) {
            self.title = title
            self.icon = icon
            self.action = action
        }
    }

    public struct Config {
        public enum Icon {
            case image(UIImage)
            case lottie(LottieResource)
        }

        public var icon: Icon
        public var title: String
        public var subtitle: String?
        public var button: ButtonConfig?

        public init(
            image: UIImage,
            title: String,
            subtitle: String? = nil,
            button: ButtonConfig? = nil
        ) {
            self.icon = .image(image)
            self.title = title
            self.subtitle = subtitle
            self.button = button
        }

        public init(
            lottieResource: LottieResource,
            title: String,
            subtitle: String? = nil,
            button: ButtonConfig? = nil
        ) {
            self.icon = .lottie(lottieResource)
            self.title = title
            self.subtitle = subtitle
            self.button = button
        }
    }

    public var config: Config

    public init(config: Config) {
        self.config = config
    }

    public var body: some View {
        VStack(spacing: 0) {
            iconView
                .padding(.top, Layout.imageTopPadding)
            Text(config.title)
                .textStyle(.h3)
                .foregroundStyle(.textPrimary)
                .multilineTextAlignment(.center)
                .padding(.top, Layout.titleTopPadding)

            if let subtitle = config.subtitle {
                Text(subtitle)
                    .textStyle(.body1)
                    .foregroundStyle(.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.top, Layout.subtitleTopPadding)
            }
            if let button = config.button {
                ButtonView(
                    config: ButtonView.Config(
                        title: button.title,
                        size: .small,
                        appearance: .secondary,
                        icon: button.icon.map {
                            ButtonView.Icon(image: $0)
                        },
                        action: button.action
                    )
                )
                .padding(.top, Layout.buttonTopPadding)
            }
        }
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private var iconView: some View {
        switch config.icon {
        case let .image(image):
            Image(uiImage: image)
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .frame(
                    width: Layout.iconSize,
                    height: Layout.iconSize
                )
                .foregroundStyle(.accentBlue)
        case let .lottie(resource):
            PlaceholderLottieView(resource: resource)
                .frame(
                    width: Layout.iconSize,
                    height: Layout.iconSize
                )
        }
    }
}

extension PlaceholderView {
    enum Layout {
        static let iconSize: CGFloat = 56
        static let imageTopPadding: CGFloat = 32
        static let titleTopPadding: CGFloat = 16
        static let subtitleTopPadding: CGFloat = 4
        static let buttonTopPadding: CGFloat = 16
    }
}

#Preview {
    PlaceholderView(
        config: PlaceholderView.Config(
            lottieResource: .exclamationmarkCircle,
            title: "Something went wrong",
            subtitle: "We couldn’t load content.",
            button: PlaceholderView.ButtonConfig(
                title: "Retry",
                icon: .TKUIKit.Icons.Size16.refresh,
                action: {}
            )
        )
    )
    .debugPreview(background: .page)
    .tkThemed()
}

private struct PlaceholderLottieView: UIViewRepresentable {
    let resource: LottieResource

    func makeUIView(context: Context) -> PlaceholderLottieContainerView {
        let view = PlaceholderLottieContainerView()
        view.configure(resource: resource)
        return view
    }

    func updateUIView(_ view: PlaceholderLottieContainerView, context: Context) {
        view.configure(resource: resource)
    }
}

private final class PlaceholderLottieContainerView: UIView {
    private let animationView = LottieAnimationView()
    private var resource: LottieResource?
    private var didPlayInitialAnimation = false

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        guard window != nil else { return }
        playInitialAnimationIfNeeded()
    }

    func configure(resource: LottieResource) {
        guard self.resource != resource else { return }
        self.resource = resource
        didPlayInitialAnimation = false
        animationView.animation = LottieAnimation.named(
            resource.name,
            bundle: resource.bundle,
            subdirectory: resource.subdirectory
        )
        if window != nil {
            playInitialAnimationIfNeeded()
        }
    }
}

private extension PlaceholderLottieContainerView {
    func setup() {
        animationView.loopMode = .playOnce
        animationView.contentMode = .scaleAspectFit
        animationView.backgroundBehavior = .pauseAndRestore
        animationView.isUserInteractionEnabled = false
        animationView.isAccessibilityElement = false
        animationView.translatesAutoresizingMaskIntoConstraints = false

        addSubview(animationView)
        NSLayoutConstraint.activate([
            animationView.leadingAnchor.constraint(equalTo: leadingAnchor),
            animationView.trailingAnchor.constraint(equalTo: trailingAnchor),
            animationView.topAnchor.constraint(equalTo: topAnchor),
            animationView.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])

        let tapRecognizer = UITapGestureRecognizer(
            target: self,
            action: #selector(handleTap)
        )
        addGestureRecognizer(tapRecognizer)
    }

    @objc func handleTap() {
        playFromBeginning()
    }

    func playInitialAnimationIfNeeded() {
        guard !didPlayInitialAnimation else { return }
        didPlayInitialAnimation = true
        playFromBeginning()
    }

    func playFromBeginning() {
        animationView.stop()
        animationView.currentProgress = 0
        animationView.play()
    }
}
