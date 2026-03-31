import UIKit

public final class TKBottomSheetHeaderView: UIView, ConfigurableView {
    let titleContainer = UIView()
    let titleLabel = UILabel()
    let subtitleLabel = UILabel()
    let closeButton = TKUIHeaderIconButton()
    let leftButtonContainer = UIView()
    let closeButtonContainer = UIView()
    private let titleVerticalStackView: UIStackView = {
        let stackView = UIStackView()
        stackView.axis = .vertical
        return stackView
    }()

    private let titleHoriontalStackView: UIStackView = {
        let stackView = UIStackView()
        stackView.alignment = .center
        stackView.axis = .horizontal
        return stackView
    }()

    // MARK: - Init

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - ConfigurableView

    public func configure(model: TKPullCardHeaderItem?) {
        titleLabel.text = nil
        subtitleLabel.text = nil
        leftButtonContainer.subviews.forEach { $0.removeFromSuperview() }
        titleVerticalStackView.arrangedSubviews.forEach { $0.removeFromSuperview() }

        guard let model = model else {
            titleCenterXConstraint.isActive = false
            titleLeftButtonConstraint.isActive = false
            titleLeftEdgeConstraint.isActive = true
            closeButtonContainer.isHidden = false
            return
        }

        closeButtonContainer.isHidden = model.isCloseButtonHidden

        switch model.title {
        case let .title(title, subtitle):
            titleVerticalStackView.addArrangedSubview(titleLabel)
            titleVerticalStackView.addArrangedSubview(subtitleLabel)
            titleLabel.attributedText = title.withTextStyle(
                .h3,
                color: .Text.primary,
                alignment: .left,
                lineBreakMode: .byTruncatingTail
            )
            subtitleLabel.attributedText = subtitle
        case let .customView(customView):
            titleVerticalStackView.addArrangedSubview(customView)
        }

        if let leftButtonModel = model.leftButton {
            let leftButton: UIControl = {
                switch leftButtonModel.model {
                case let .titleIcon(model):
                    let button = TKUIHeaderTitleIconButton()
                    button.configure(model: model)
                    button.addTapAction { [unowned button] in
                        leftButtonModel.action(button)
                    }
                    return button
                case let .icon(model):
                    let button = TKUIHeaderIconButton()
                    button.configure(model: model)
                    button.addTapAction { [unowned button] in
                        leftButtonModel.action(button)
                    }
                    return button
                }
            }()
            leftButton.isEnabled = leftButtonModel.isEnabled
            leftButtonContainer.addSubview(leftButton)
            leftButton.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                leftButton.topAnchor.constraint(equalTo: leftButtonContainer.topAnchor),
                leftButton.leftAnchor.constraint(equalTo: leftButtonContainer.leftAnchor),
                leftButton.bottomAnchor.constraint(equalTo: leftButtonContainer.bottomAnchor),
                leftButton.rightAnchor.constraint(equalTo: leftButtonContainer.rightAnchor),
            ])

            if !model.isTitleCentered {
                titleLeftEdgeConstraint.isActive = false
                titleLeftButtonConstraint.isActive = true
                titleCenterXConstraint.isActive = true
            }
        }

        if model.isTitleCentered {
            titleLeftEdgeConstraint.isActive = false
            titleLeftButtonConstraint.isActive = false
            titleCenterXConstraint.isActive = true
        } else if model.leftButton == nil {
            titleCenterXConstraint.isActive = false
            titleLeftButtonConstraint.isActive = false
            titleLeftEdgeConstraint.isActive = true
        }

        titleLeftEdgeConstraint.constant = model.contentInsets.left
        closeButtonTopConstraint.constant = model.contentInsets.top
        closeButtonRightConstraint.constant = -model.contentInsets.right
        closeButtonBottomConstraint.constant = -model.contentInsets.bottom
        leftButtonTopConstraint.constant = model.contentInsets.top
        leftButtonLeftConstraint.constant = model.contentInsets.left
    }

    lazy var titleCenterXConstraint: NSLayoutConstraint = titleVerticalStackView.centerXAnchor
        .constraint(equalTo: centerXAnchor)
        .withPriority(.defaultHigh)

    lazy var titleLeftEdgeConstraint: NSLayoutConstraint = titleVerticalStackView.leftAnchor.constraint(
        equalTo: leftAnchor,
        constant: TKPullCardHeaderItem.defaultContentInsets.left
    )

    lazy var titleLeftButtonConstraint: NSLayoutConstraint = titleVerticalStackView.leftAnchor
        .constraint(greaterThanOrEqualTo: leftButtonContainer.rightAnchor)

    lazy var closeButtonTopConstraint = closeButtonContainer.topAnchor.constraint(
        equalTo: topAnchor,
        constant: TKPullCardHeaderItem.defaultContentInsets.top
    )

    lazy var closeButtonRightConstraint = closeButtonContainer.rightAnchor.constraint(
        equalTo: rightAnchor,
        constant: -TKPullCardHeaderItem.defaultContentInsets.right
    ).withPriority(.defaultHigh)

    lazy var closeButtonBottomConstraint = closeButtonContainer.bottomAnchor.constraint(
        equalTo: bottomAnchor,
        constant: -TKPullCardHeaderItem.defaultContentInsets.bottom
    ).withPriority(.defaultHigh)

    lazy var leftButtonTopConstraint = leftButtonContainer.topAnchor.constraint(
        equalTo: topAnchor,
        constant: TKPullCardHeaderItem.defaultContentInsets.top
    )

    lazy var leftButtonLeftConstraint = leftButtonContainer.leftAnchor.constraint(
        equalTo: leftAnchor,
        constant: TKPullCardHeaderItem.defaultContentInsets.left
    )
}

private extension TKBottomSheetHeaderView {
    func setup() {
        backgroundColor = .Background.page
        closeButtonContainer.addSubview(closeButton)
        addSubview(closeButtonContainer)
        addSubview(leftButtonContainer)
        addSubview(titleHoriontalStackView)

        titleHoriontalStackView.addArrangedSubview(titleVerticalStackView)

        closeButton.configure(
            model: TKUIHeaderButtonIconContentView.Model(image: .TKUIKit.Icons.Size16.close)
        )

        setupConstraints()
    }

    func setupConstraints() {
        titleHoriontalStackView.translatesAutoresizingMaskIntoConstraints = false
        closeButton.translatesAutoresizingMaskIntoConstraints = false
        closeButtonContainer.translatesAutoresizingMaskIntoConstraints = false
        leftButtonContainer.translatesAutoresizingMaskIntoConstraints = false

        closeButton.setContentCompressionResistancePriority(.required, for: .horizontal)
        leftButtonContainer.setContentCompressionResistancePriority(.required, for: .horizontal)

        NSLayoutConstraint.activate([
            closeButtonTopConstraint,
            closeButtonRightConstraint,
            closeButtonBottomConstraint,

            closeButton.topAnchor.constraint(equalTo: closeButtonContainer.topAnchor),
            closeButton.leftAnchor.constraint(equalTo: closeButtonContainer.leftAnchor),
            closeButton.rightAnchor.constraint(equalTo: closeButtonContainer.rightAnchor),
            closeButton.bottomAnchor.constraint(lessThanOrEqualTo: closeButtonContainer.bottomAnchor),

            titleHoriontalStackView.topAnchor.constraint(equalTo: topAnchor, constant: 8),
            titleHoriontalStackView.bottomAnchor.constraint(equalTo: bottomAnchor, constant: 8).withPriority(.defaultHigh),
            titleHoriontalStackView.rightAnchor.constraint(lessThanOrEqualTo: closeButtonContainer.leftAnchor),
            titleHoriontalStackView.centerYAnchor.constraint(equalTo: centerYAnchor),

            leftButtonTopConstraint,
            leftButtonLeftConstraint,
        ])
    }
}
