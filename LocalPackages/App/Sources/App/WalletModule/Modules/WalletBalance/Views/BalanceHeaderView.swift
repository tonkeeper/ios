import SnapKit
import TKCore
import TKUIKit
import UIKit

final class BalanceHeaderView: UIView, ConfigurableView {
    private let balanceView = BalanceHeaderBalanceView()
    private let buttonsRedesignView: WalletBalanceHeaderButtonsRedesignView

    private let stackView: UIStackView = {
        let stackView = UIStackView()
        stackView.axis = .vertical
        return stackView
    }()

    init(
        tooltipsService: TooltipsService,
        frame: CGRect = .zero
    ) {
        buttonsRedesignView = WalletBalanceHeaderButtonsRedesignView(tooltipsService: tooltipsService)
        super.init(frame: frame)
        setup()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    struct Model {
        let balanceModel: BalanceHeaderBalanceView.Model
        let buttonsModel: WalletBalanceHeaderButtonsRedesignView.Model
    }

    func configure(model: Model) {
        balanceView.configure(model: model.balanceModel)
        buttonsRedesignView.configure(model: model.buttonsModel)
    }
}

private extension BalanceHeaderView {
    func setup() {
        addSubview(stackView)
        stackView.addArrangedSubview(balanceView)
        stackView.addArrangedSubview(buttonsRedesignView)

        setupConstraints()
    }

    func setupConstraints() {
        stackView.snp.makeConstraints { make in
            make.top.leading.trailing.equalTo(self)
            make.bottom.equalTo(self).priority(.high)
        }
    }
}
