import UIKit

final class AddWalletOptionPickerSectionHeaderView: UICollectionReusableView {
    let titleLabel = UILabel()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
        setupConstraints()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func setup() {
        addSubview(titleLabel)
        titleLabel.numberOfLines = 0
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.setContentHuggingPriority(.required, for: .vertical)
    }

    func setupConstraints() {
        NSLayoutConstraint.activate([
            titleLabel.leadingAnchor.constraint(equalTo: leadingAnchor),
            titleLabel.trailingAnchor.constraint(equalTo: trailingAnchor),
            titleLabel.topAnchor.constraint(equalTo: topAnchor, constant: 12),
            titleLabel.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -12),
        ])
    }
}
