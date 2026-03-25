import TKUIKit
import UIKit

final class SendAssetDetailsView: UIView {
    struct Model {
        struct Row {
            let title: String
            let value: String
        }

        let rows: [Row]
    }

    private let stack = UIStackView()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setup() {
        backgroundColor = .Background.content
        layer.cornerRadius = 16
        stack.axis = .vertical
        stack.spacing = 12
        addSubview(stack)

        stack.snp.makeConstraints { make in
            make.edges.equalTo(self).inset(16)
        }
    }

    func configure(model: Model) {
        stack.arrangedSubviews.forEach { $0.removeFromSuperview() }

        for row in model.rows {
            let rowView = SendAssetDetailRowView()
            rowView.configure(title: row.title, value: row.value)
            stack.addArrangedSubview(rowView)
        }
    }
}

private final class SendAssetDetailRowView: UIView {
    private let titleLabel = UILabel()
    private let valueLabel = UILabel()

    override init(frame: CGRect) {
        super.init(frame: frame)

        titleLabel.font = TKTextStyle.body2.font
        titleLabel.textColor = .Text.secondary
        valueLabel.font = TKTextStyle.label2.font
        valueLabel.textColor = .Text.primary

        addSubview(titleLabel)
        addSubview(valueLabel)

        titleLabel.snp.makeConstraints { make in
            make.leading.top.bottom.equalTo(self)
        }
        valueLabel.snp.makeConstraints { make in
            make.trailing.top.bottom.equalTo(self)
            make.leading.greaterThanOrEqualTo(titleLabel.snp.trailing).offset(8)
        }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(title: String, value: String) {
        titleLabel.text = title
        valueLabel.text = value
    }
}
