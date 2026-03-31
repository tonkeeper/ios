import SnapKit
import TKUIKit
import UIKit

final class BalanceHeaderView: UIView, ConfigurableView {
    private let balanceView = BalanceHeaderBalanceView()
    private let buttonsView = WalletBalanceHeaderButtonsView()
    private let buttonsRedesignView = WalletBalanceHeaderButtonsRedesignView()
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

    enum ButtonsContent {
        case classic(WalletBalanceHeaderButtonsView.Model)
        case redesign(WalletBalanceHeaderButtonsRedesignView.Model)
    }

    struct Model {
        let balanceModel: BalanceHeaderBalanceView.Model
        let buttonsContent: ButtonsContent
        let updatesViewModel: WalletBalanceUpdatesView.Model?
        let updatesAction: (() -> Void)?

        var hasWithdrawTooltip: Bool {
            guard case let .redesign(model) = buttonsContent else { return false }
            return model.tooltip != nil
        }
    }

    func configure(model: Model) {
        balanceView.configure(model: model.balanceModel)

        switch model.buttonsContent {
        case let .classic(classicModel):
            buttonsView.configure(model: classicModel)
            buttonsView.isHidden = false
            buttonsRedesignView.isHidden = true
        case let .redesign(redesignModel):
            buttonsRedesignView.configure(model: redesignModel)
            buttonsView.isHidden = true
            buttonsRedesignView.isHidden = false
        }

        if let updatesViewModel = model.updatesViewModel {
            updatesView.isHidden = false
            updatesView.configure(model: updatesViewModel)
            updatesView.setAction(model.updatesAction)
        } else {
            updatesView.isHidden = true
        }
    }

    func isWithdrawTooltipContains(point: CGPoint) -> Bool {
        let pointInButtonsView = convert(point, to: buttonsRedesignView)
        return buttonsRedesignView.isTooltipContains(point: pointInButtonsView)
    }
}

private extension BalanceHeaderView {
    func setup() {
        addSubview(stackView)
        stackView.addArrangedSubview(balanceView)
        stackView.addArrangedSubview(buttonsView)
        stackView.addArrangedSubview(buttonsRedesignView)
        stackView.addArrangedSubview(updatesView)

        buttonsRedesignView.isHidden = true

        setupConstraints()
    }

    func setupConstraints() {
        stackView.snp.makeConstraints { make in
            make.edges.equalTo(self)
        }
    }
}
