import TKUIKit
import UIKit

final class NativeSwapTransactionConfirmationView: UIView {
    let titleView = TKUINavigationBarTitleView()
    let navigationBar = TKUINavigationBar()

    private let modalContentContainer = UIView()

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

private extension NativeSwapTransactionConfirmationView {
    func setup() {
        navigationBar.centerView = titleView

        addSubview(modalContentContainer)
        addSubview(navigationBar)

        navigationBar.snp.makeConstraints { make in
            make.top.left.right.equalTo(self)
        }

        modalContentContainer.snp.makeConstraints { make in
            make.top.equalTo(navigationBar.snp.bottom)
            make.left.bottom.right.equalTo(self)
        }
    }
}
