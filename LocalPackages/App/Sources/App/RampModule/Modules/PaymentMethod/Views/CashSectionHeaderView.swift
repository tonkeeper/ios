import KeeperCore
import SnapKit
import TKUIKit
import UIKit

final class CashSectionHeaderView: UIView, ReusableView, TKCollectionViewSupplementaryContainerViewContentView, ConfigurableView {
    var didTapCurrencyButton: (() -> Void)?

    struct Model: Hashable {
        let title: String
        let currencyCode: String?
        let currencyImage: URL?
        let padding: UIEdgeInsets
    }

    private let titleLabel: UILabel = {
        let label = UILabel()
        label.font = TKTextStyle.label1.font
        label.textColor = .Text.primary
        label.numberOfLines = 0
        return label
    }()

    private let currencyButton = CurrencyPickerButton()
    private let spacerView = UIView()

    private var padding: UIEdgeInsets = .zero

    private let stackView: UIStackView = {
        let stack = UIStackView()
        stack.axis = .horizontal
        stack.alignment = .center
        stack.spacing = 12
        return stack
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func sizeThatFits(_ size: CGSize) -> CGSize {
        let height = systemLayoutSizeFitting(
            CGSize(width: size.width, height: 0),
            withHorizontalFittingPriority: .required,
            verticalFittingPriority: .defaultLow
        ).height + padding.top + padding.bottom

        return CGSize(width: size.width, height: max(48, height))
    }

    func prepareForReuse() {
        titleLabel.text = nil
        currencyButton.configuration = nil
    }

    func configure(model: Model) {
        titleLabel.text = model.title
        padding = model.padding

        currencyButton.isHidden = model.currencyCode == nil
        currencyButton.configuration = CurrencyPickerButton.Configuration(
            currencyCode: model.currencyCode,
            image: .urlImage(model.currencyImage)
        )
    }

    private func setup() {
        addSubview(stackView)
        stackView.addArrangedSubview(titleLabel)
        stackView.addArrangedSubview(spacerView)
        stackView.addArrangedSubview(currencyButton)

        titleLabel.setContentHuggingPriority(.defaultLow, for: .horizontal)
        currencyButton.setContentHuggingPriority(.required, for: .horizontal)

        currencyButton.didTap = { [weak self] in
            self?.didTapCurrencyButton?()
        }

        stackView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
    }
}
