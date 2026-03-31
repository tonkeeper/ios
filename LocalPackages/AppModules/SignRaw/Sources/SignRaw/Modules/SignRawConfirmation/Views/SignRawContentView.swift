import TKUIKit
import UIComponents
import UIKit

final class SignRawContentView: UIView {
    struct Configuration: TKPopUp.Item {
        let actionsConfiguration: AccountEventCellContentView.Model

        var bottomSpace: CGFloat {
            0
        }

        func getView() -> UIView {
            let view = SignRawContentView()
            view.configuration = self
            return view
        }
    }

    var configuration: Configuration? {
        didSet {
            didUpdateConfiguration()
            invalidateIntrinsicContentSize()
            setNeedsLayout()
        }
    }

    private let actionsView = AccountEventCellContentView()

    // MARK: - Init

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

private extension SignRawContentView {
    func setup() {
        actionsView.isUserInteractionEnabled = false

        addSubview(actionsView)
        setupConstraints()
    }

    func setupConstraints() {
        actionsView.snp.makeConstraints { make in
            make.edges.equalTo(self)
        }
    }

    func didUpdateConfiguration() {
        guard let configuration else {
            actionsView.configure(model: AccountEventCellContentView.Model(actions: []))
            return
        }

        actionsView.configure(model: configuration.actionsConfiguration)
    }
}
