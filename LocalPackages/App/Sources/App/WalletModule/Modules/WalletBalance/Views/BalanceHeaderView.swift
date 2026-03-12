import SnapKit
import TKUIKit
import UIKit

final class BalanceHeaderView: UIView, ConfigurableView {
    private let balanceView = BalanceHeaderBalanceView()
    private let buttonsView = WalletBalanceHeaderButtonsView()
    private let updatesView = WalletBalanceUpdatesView()

    private let stackView: UIStackView = {
        let stackView = UIStackView()
        stackView.axis = .vertical
        return stackView
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    struct Model {
        let balanceModel: BalanceHeaderBalanceView.Model
        let buttonsViewModel: WalletBalanceHeaderButtonsView.Model
        let updatesViewModel: WalletBalanceUpdatesView.Model?
        let updatesAction: (() -> Void)?
    }

    func configure(model: Model) {
        balanceView.configure(model: model.balanceModel)
        buttonsView.configure(model: model.buttonsViewModel)

        if let updatesViewModel = model.updatesViewModel {
            updatesView.isHidden = false
            updatesView.configure(model: updatesViewModel)
            updatesView.setAction(model.updatesAction)
        } else {
            updatesView.isHidden = true
        }
    }
}

private extension BalanceHeaderView {
    func setup() {
        addSubview(stackView)
        stackView.addArrangedSubview(balanceView)
        stackView.addArrangedSubview(buttonsView)
        stackView.addArrangedSubview(updatesView)

        setupConstraints()
    }

    func setupConstraints() {
        stackView.snp.makeConstraints { make in
            make.edges.equalTo(self)
        }
    }
}
