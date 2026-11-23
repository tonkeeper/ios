import UIKit

public final class TKPillButton: UIView {
    public struct Configuration {
        public struct Button {
            public let icon: UIImage
            /// The icon the button gets as its own item in a system navigation bar; without it the pill
            /// stays one custom view there.
            public let systemBarIcon: UIImage?
            /// Handed the view a popup anchors to: the pill, or the bar item it became.
            public let action: (_ sourceView: UIView) -> Void

            public init(icon: UIImage, systemBarIcon: UIImage? = nil, action: @escaping (_ sourceView: UIView) -> Void) {
                self.icon = icon
                self.systemBarIcon = systemBarIcon
                self.action = action
            }
        }

        public let leftButton: Button
        public let rightButton: Button

        public init(leftButton: Button, rightButton: Button) {
            self.leftButton = leftButton
            self.rightButton = rightButton
        }

        public static var `default`: Configuration {
            Configuration(
                leftButton: Button(icon: .TKUIKit.Icons.Size16.ellipses, action: { _ in }),
                rightButton: Button(icon: .TKUIKit.Icons.Size16.close, action: { _ in })
            )
        }
    }

    public var configuration: Configuration = .default {
        didSet {
            didUpdateConfiguration()
        }
    }

    public var rightButtonAccessibilityIdentifier: String? {
        didSet {
            rightButton.accessibilityIdentifier = rightButtonAccessibilityIdentifier
            rightButton.isAccessibilityElement = (rightButtonAccessibilityIdentifier != nil)
        }
    }

    /// Both halves as system bar items, left first, when each has a `systemBarIcon`.
    var systemBarItems: [TKUINavigationBar.SystemBarItem]? {
        let left = configuration.leftButton
        let right = configuration.rightButton
        guard let leftIcon = left.systemBarIcon, let rightIcon = right.systemBarIcon else { return nil }
        return [
            TKUINavigationBar.SystemBarItem(image: leftIcon, action: left.action),
            TKUINavigationBar.SystemBarItem(
                image: rightIcon,
                accessibilityIdentifier: rightButtonAccessibilityIdentifier,
                action: right.action
            ),
        ]
    }

    private let leftButton = TKButton()
    private let rightButton = TKButton()
    private let divider = UIView()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override public func layoutSubviews() {
        super.layoutSubviews()
        layer.cornerRadius = bounds.height / 2
    }

    private func setup() {
        backgroundColor = .Button.secondaryBackground
        layer.masksToBounds = true

        divider.backgroundColor = .Background.contentTint

        addSubview(leftButton)
        addSubview(divider)
        addSubview(rightButton)

        setupConstraints()

        didUpdateConfiguration()
    }

    private func setupConstraints() {
        leftButton.setContentCompressionResistancePriority(.required, for: .horizontal)
        rightButton.setContentCompressionResistancePriority(.required, for: .horizontal)
        divider.setContentCompressionResistancePriority(.required, for: .horizontal)

        leftButton.snp.makeConstraints { make in
            make.left.top.bottom.equalTo(self)
        }
        divider.snp.makeConstraints { make in
            make.top.bottom.equalTo(self).inset(8)
            make.width.equalTo(1)
            make.left.equalTo(leftButton.snp.right)
        }
        rightButton.snp.makeConstraints { make in
            make.top.right.bottom.equalTo(self)
            make.left.equalTo(divider.snp.right)
        }
    }

    private func didUpdateConfiguration() {
        func buttonConfiguration(configuration: Configuration.Button) -> TKButton.Configuration {
            TKButton.Configuration(
                content: TKButton.Configuration.Content(icon: configuration.icon),
                contentPadding: UIEdgeInsets(top: 8, left: 12, bottom: 8, right: 12),
                iconTintColor: .Icon.primary,
                contentAlpha: [
                    .normal: 1,
                    .highlighted: 0.44,
                ],
                action: { [weak self] in
                    guard let self else { return }
                    configuration.action(self)
                }
            )
        }

        leftButton.configuration = buttonConfiguration(configuration: configuration.leftButton)
        rightButton.configuration = buttonConfiguration(configuration: configuration.rightButton)
    }
}
