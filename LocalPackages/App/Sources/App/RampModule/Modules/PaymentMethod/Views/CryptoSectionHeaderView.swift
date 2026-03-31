import SnapKit
import TKUIKit
import UIKit

final class CryptoSectionHeaderView: UIView, ReusableView, TKCollectionViewSupplementaryContainerViewContentView, ConfigurableView {
    struct Model: Hashable {
        let title: String
        let subtitle: String?
        let padding: UIEdgeInsets
    }

    private let titleLabel: UILabel = {
        let label = UILabel()
        label.font = TKTextStyle.label1.font
        label.textColor = .Text.primary
        label.numberOfLines = 0
        return label
    }()

    private let subtitleLabel: UILabel = {
        let label = UILabel()
        label.font = TKTextStyle.body2.font
        label.textColor = .Text.secondary
        label.numberOfLines = 0
        return label
    }()

    private var padding: UIEdgeInsets = .zero

    private let stackView: UIStackView = {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.alignment = .leading
        stack.spacing = 2
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
        let availableWidth = max(0, size.width - padding.left - padding.right)
        let maxSize = CGSize(width: availableWidth, height: .greatestFiniteMagnitude)

        let titleHeight = titleLabel.sizeThatFits(maxSize).height
        let subtitleHeight: CGFloat
        if subtitleLabel.isHidden {
            subtitleHeight = 0
        } else {
            subtitleHeight = subtitleLabel.sizeThatFits(maxSize).height
        }

        let spacing = subtitleHeight > 0 ? stackView.spacing : 0
        let contentHeight = titleHeight + spacing + subtitleHeight
        let totalHeight = padding.top + contentHeight + padding.bottom

        return CGSize(width: size.width, height: totalHeight)
    }

    func prepareForReuse() {
        titleLabel.text = nil
        subtitleLabel.text = nil
        subtitleLabel.isHidden = true
    }

    func configure(model: Model) {
        titleLabel.text = model.title
        padding = model.padding

        if let subtitle = model.subtitle, !subtitle.isEmpty {
            subtitleLabel.text = subtitle
            subtitleLabel.isHidden = false
        } else {
            subtitleLabel.text = nil
            subtitleLabel.isHidden = true
        }
    }

    private func setup() {
        addSubview(stackView)
        stackView.addArrangedSubview(titleLabel)
        stackView.addArrangedSubview(subtitleLabel)

        stackView.snp.makeConstraints { make in
            make.leading.trailing.centerY.equalToSuperview()
        }
    }
}
