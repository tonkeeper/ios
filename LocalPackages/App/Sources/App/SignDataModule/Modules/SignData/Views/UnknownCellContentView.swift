import TKLocalize
import TKUIKit
import UIKit

public final class UnknownCellContentView: UIView, TKPopUp.Item {
    public var bottomSpace: CGFloat = 12

    public func getView() -> UIView {
        return self
    }

    private let stackView = UIStackView()
    private let titleLabel: UILabel = {
        let label = UILabel()
        label.numberOfLines = 0
        return label
    }()

    private let subtitleLabel: UILabel = {
        let label = UILabel()
        label.numberOfLines = 0
        return label
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setup() {
        addSubview(stackView)

        titleLabel.attributedText = TKLocales.SignData.UnknownCell.title.withTextStyle(.label1, color: .Constant.black)

        subtitleLabel.attributedText = TKLocales.SignData.UnknownCell.subtitle.withTextStyle(.body2, color: .Constant.black)

        backgroundColor = .Accent.orange
        layer.cornerRadius = 16
        layer.masksToBounds = true

        stackView.axis = .vertical
        stackView.alignment = .leading
        stackView.distribution = .fill

        stackView.addArrangedSubview(titleLabel)
        stackView.addArrangedSubview(subtitleLabel)

        setupConstraints()
    }

    private func setupConstraints() {
        stackView.snp.makeConstraints { make in
            make.top.equalTo(self).offset(12)
            make.bottom.equalTo(self).offset(-12)
            make.left.equalTo(self).offset(16)
            make.right.equalTo(self).offset(-16)
        }
    }
}
