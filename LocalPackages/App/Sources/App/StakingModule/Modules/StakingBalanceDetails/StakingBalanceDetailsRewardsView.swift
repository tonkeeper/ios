import TKUIKit
import UIKit

final class StakingBalanceDetailsRewardsView: TKView, ConfigurableView {
    struct Model {
        struct Card {
            let title: String
            let value: String
            let fiatValue: String
        }

        let title: String
        let cards: [Card]
    }

    private let titleLabel = UILabel()
    private let infoButton = UIButton(type: .system)
    var didTapInfo: ((UIView) -> Void)?
    private let cardsStackView = UIStackView()

    func configure(model: Model) {
        titleLabel.attributedText = model.title.withTextStyle(.h3, color: .Text.primary)

        cardsStackView.arrangedSubviews.forEach { $0.removeFromSuperview() }
        for card in model.cards {
            let cardView = CardView()
            cardView.configure(model: card)
            cardsStackView.addArrangedSubview(cardView)
        }
    }

    override func setup() {
        super.setup()

        var infoConfiguration = UIButton.Configuration.plain()
        infoConfiguration.image = .TKUIKit.Icons.Size16.informationCircle
        infoConfiguration.baseForegroundColor = .Icon.tertiary
        infoConfiguration.contentInsets = NSDirectionalEdgeInsets(top: 5, leading: 6, bottom: 3, trailing: 6)
        infoButton.configuration = infoConfiguration
        infoButton.setContentHuggingPriority(.required, for: .horizontal)
        infoButton.addAction(UIAction { [weak self] _ in
            guard let self else { return }
            self.didTapInfo?(self.infoButton)
        }, for: .touchUpInside)

        cardsStackView.axis = .horizontal
        cardsStackView.spacing = 8
        cardsStackView.distribution = .fillEqually

        let titleStackView = UIStackView(arrangedSubviews: [titleLabel, infoButton, UIView()])
        titleStackView.axis = .horizontal
        titleStackView.alignment = .center
        titleStackView.spacing = 0

        addSubview(titleStackView)
        addSubview(cardsStackView)

        titleStackView.snp.makeConstraints { make in
            make.top.left.right.equalTo(self)
            make.height.equalTo(56)
        }

        cardsStackView.snp.makeConstraints { make in
            make.top.equalTo(titleStackView.snp.bottom)
            make.left.right.bottom.equalTo(self)
        }
    }
}

private extension StakingBalanceDetailsRewardsView {
    final class CardView: TKView, ConfigurableView {
        private let titleLabel = UILabel()
        private let valueLabel = UILabel()
        private let fiatValueLabel = UILabel()

        func configure(model: Model.Card) {
            titleLabel.attributedText = model.title.withTextStyle(.body2, color: .Text.secondary)
            valueLabel.attributedText = model.value.withTextStyle(.label1, color: .Text.primary)
            fiatValueLabel.attributedText = model.fiatValue.withTextStyle(.body2, color: .Text.secondary)
        }

        override func setup() {
            super.setup()

            backgroundColor = .Background.content
            layer.cornerRadius = 16
            layer.cornerCurve = .continuous

            let stackView = UIStackView(arrangedSubviews: [titleLabel, valueLabel, fiatValueLabel])
            stackView.axis = .vertical
            stackView.alignment = .leading

            addSubview(stackView)
            stackView.snp.makeConstraints { make in
                make.edges.equalTo(self).inset(UIEdgeInsets(top: 12, left: 16, bottom: 12, right: 16))
            }
        }
    }
}
