import KeeperCore
import TKLocalize
import TKUIKit
import UIKit

final class WalletBalanceUpdatesView: UIControl, ConfigurableView {
    private let stackView: UIStackView = {
        let stackView = UIStackView()
        stackView.axis = .horizontal
        stackView.alignment = .center
        stackView.spacing = 0
        return stackView
    }()

    private let icon = TKImageView()
    private let titleLabel = UILabel()
    private let chevronIcon: TKImageView = {
        let icon = TKImageView()

        icon.tintColor = .Icon.tertiary
        icon.image = .image(.TKUIKit.Icons.Size16.chevronRight)

        return icon
    }()

    override var isHighlighted: Bool {
        didSet {
            alpha = self.isHighlighted ? 0.8 : 1.0
        }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    struct Model {
        let story: Story?

        init(story: Story?) {
            self.story = story
        }
    }

    func configure(model: Model) {
        if let story = model.story {
            titleLabel.attributedText = story.main_screen.title.withTextStyle(.body3Alternate, color: .Text.primary)
            icon.configure(model: TKImageView.Model(
                image: .urlImage(story.main_screen.icon),
                size: .size(CGSize(width: 20, height: 20)),
                corners: .none
            ))
            icon.isHidden = false
        } else {
            titleLabel.attributedText = TKLocales.StoriesUpdates.allUpdates
                .withTextStyle(.body3Alternate, color: .Text.primary)
            icon.isHidden = true
        }
    }

    func setAction(_ action: (() -> Void)?) {
        removeTarget(nil, action: nil, for: .touchUpInside)
        addAction(UIAction(handler: { _ in
            action?()
        }), for: .touchUpInside)
    }
}

private extension WalletBalanceUpdatesView {
    func setup() {
        titleLabel.numberOfLines = 1

        isUserInteractionEnabled = true

        stackView.isUserInteractionEnabled = false
        icon.isUserInteractionEnabled = false
        titleLabel.isUserInteractionEnabled = false
        chevronIcon.isUserInteractionEnabled = false

        stackView.addArrangedSubview(icon)
        stackView.setCustomSpacing(6, after: icon)
        stackView.addArrangedSubview(titleLabel)
        stackView.addArrangedSubview(chevronIcon)

        addSubview(stackView)
        setupConstraints()
    }

    func setupConstraints() {
        stackView.snp.makeConstraints { make in
            make.center.equalToSuperview()
            make.leading.greaterThanOrEqualToSuperview()
            make.trailing.lessThanOrEqualToSuperview()
            make.top.equalToSuperview()
            make.height.equalTo(20)
            make.bottom.equalToSuperview().inset(8)
        }
    }
}
