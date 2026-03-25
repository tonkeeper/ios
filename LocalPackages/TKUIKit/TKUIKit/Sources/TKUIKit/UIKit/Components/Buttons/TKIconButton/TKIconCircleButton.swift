import UIKit

public final class TKIconCircleButton: UIControl {
    override public var isHighlighted: Bool {
        didSet {
            updateState()
        }
    }

    override public var isEnabled: Bool {
        didSet {
            updateState()
        }
    }

    public struct Configuration {
        public let title: String?
        public let icon: UIImage?
        public let isEnable: Bool
        public let action: (() -> Void)?

        public init(
            title: String?,
            icon: UIImage?,
            isEnable: Bool = true,
            action: (() -> Void)?
        ) {
            self.title = title
            self.icon = icon
            self.isEnable = isEnable
            self.action = action
        }
    }

    public var configuration = Configuration(
        title: nil,
        icon: nil,
        action: nil
    ) {
        didSet {
            didUpdateConfiguration()
            invalidateIntrinsicContentSize()
        }
    }

    private static let circleSize: CGFloat = 44

    private let iconContainerWrapperView: UIView = {
        let view = UIView()
        view.isUserInteractionEnabled = false
        return view
    }()

    private let iconContainerView: UIView = {
        let view = UIView()
        view.backgroundColor = .Background.content
        view.layer.cornerRadius = TKIconCircleButton.circleSize / 2
        view.isUserInteractionEnabled = false
        return view
    }()

    private let iconImageView: UIImageView = {
        let view = UIImageView()
        view.contentMode = .center
        view.tintColor = .Icon.primary
        return view
    }()

    private let titleLabel = UILabel()
    private let stackView = UIStackView()

    override public init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setup() {
        stackView.axis = .vertical
        stackView.spacing = 8
        stackView.isUserInteractionEnabled = false

        iconContainerView.addSubview(iconImageView)
        iconContainerWrapperView.addSubview(iconContainerView)

        addSubview(stackView)
        stackView.addArrangedSubview(iconContainerWrapperView)
        stackView.addArrangedSubview(titleLabel)

        addAction(UIAction(handler: { [weak self] _ in
            self?.configuration.action?()
        }), for: .touchUpInside)

        setupConstraints()
    }

    private func setupConstraints() {
        stackView.snp.makeConstraints { make in
            make.edges.equalTo(self).inset(
                UIEdgeInsets(top: 8, left: 4, bottom: 8, right: 4)
            )
        }

        iconContainerWrapperView.snp.makeConstraints { make in
            make.height.greaterThanOrEqualTo(Self.circleSize)
        }

        iconContainerView.snp.makeConstraints { make in
            make.size.equalTo(Self.circleSize)
            make.center.equalToSuperview()
        }

        iconImageView.snp.makeConstraints { make in
            make.edges.equalToSuperview().inset(8)
        }
    }

    private func didUpdateConfiguration() {
        titleLabel.attributedText = configuration.title?.withTextStyle(
            .label3,
            color: .Text.secondary,
            alignment: .center
        )

        iconImageView.image = configuration.icon
        isEnabled = configuration.isEnable
    }

    private func updateState() {
        switch (isEnabled, isHighlighted) {
        case (false, _):
            stackView.alpha = 0.32
        case (true, true):
            stackView.alpha = 0.48
        case (true, false):
            stackView.alpha = 1
        }
    }
}
