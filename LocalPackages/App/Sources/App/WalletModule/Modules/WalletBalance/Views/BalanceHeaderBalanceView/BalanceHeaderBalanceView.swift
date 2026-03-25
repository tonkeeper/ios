import SnapKit
import TKUIKit
import UIKit

final class BalanceHeaderBalanceView: UIView, ConfigurableView {
    private let amountView = BalanceHeaderBalanceAmountView()
    private let statusView = BalanceHeaderBalanceStatusView()
    private let stackView = UIStackView()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    struct Model {
        let amountViewConfiguration: BalanceHeaderBalanceAmountView.Configuration
        let statusViewConfiguration: BalanceHeaderBalanceStatusView.Configuration
    }

    func configure(model: Model) {
        amountView.configuration = model.amountViewConfiguration
        statusView.configuration = model.statusViewConfiguration
    }
}

private extension BalanceHeaderBalanceView {
    func setup() {
        stackView.axis = .vertical
        stackView.addArrangedSubview(amountView)
        stackView.addArrangedSubview(TKSpacingView(verticalSpacing: .constant(4)))
        stackView.addArrangedSubview(statusView)
        stackView.addArrangedSubview(TKSpacingView(verticalSpacing: .constant(8)))

        addSubview(stackView)
        setupConstraints()
    }

    func setupConstraints() {
        stackView.snp.makeConstraints { make in
            make.edges.equalTo(self).inset(UIEdgeInsets.stackViewPadding)
        }
    }
}

private extension UIEdgeInsets {
    static var stackViewPadding = UIEdgeInsets(top: 28, left: 16, bottom: 16, right: 16)
}
