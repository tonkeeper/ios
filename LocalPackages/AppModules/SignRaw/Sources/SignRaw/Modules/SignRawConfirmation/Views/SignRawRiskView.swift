import TKUIKit
import UIKit

final class SignRawRiskView: UIView {
    private lazy var titleLabel = UILabel()
    private lazy var infoButton = TKButton()
    private lazy var stackView: UIStackView = {
        let view = UIStackView(arrangedSubviews: [titleLabel, infoButton])
        view.alignment = .center
        view.spacing = 4
        return view
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

        stackView.snp.makeConstraints {
            $0.top.bottom.equalToSuperview().inset(12)
            $0.centerX.equalToSuperview()
        }
    }
}

// MARK: -  ConfigurableView

extension SignRawRiskView: ConfigurableView {
    struct Model: TKPopUp.Item {
        var bottomSpace: CGFloat

        func getView() -> UIView {
            let view = SignRawRiskView()
            view.configure(model: self)
            return view
        }

        let title: String
        let isRisk: Bool
        let action: (() -> Void)?
    }

    func configure(model: Model) {
        let accentColor: UIColor = model.isRisk ? .Accent.orange : .Text.secondary
        let attributedText = model.title.withTextStyle(.body2, color: accentColor, alignment: .center)
        titleLabel.attributedText = attributedText
        infoButton.configuration = .init(
            content: .init(icon: .TKUIKit.Icons.Size16.informationCircle),
            iconTintColor: accentColor,
            action: model.action
        )
    }
}
