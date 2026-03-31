import SnapKit
import TKUIKit
import UIKit

final class RampMerchantPopUpView: UIView {
    private let modalContentContainer = UIView()

    // MARK: - Init

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func embedContent(_ view: UIView) {
        modalContentContainer.addSubview(view)

        view.snp.makeConstraints { make in
            make.edges.equalTo(modalContentContainer)
        }
    }
}

// MARK: - Private

private extension RampMerchantPopUpView {
    func setup() {
        backgroundColor = .Background.page

        addSubview(modalContentContainer)

        setupConstraints()
    }

    func setupConstraints() {
        modalContentContainer.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
    }
}
