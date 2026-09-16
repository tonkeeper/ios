import SnapKit
import TKUIKit
import UIKit

final class WalletContainerView: UIView {
    let walletBalanceContainerView = UIView()
    private(set) var topBarView: UIView?

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func setTopBarView(_ view: UIView) {
        topBarView = view
        addSubview(view)

        view.snp.makeConstraints { make in
            make.top.left.right.equalTo(self)
            make.bottom.equalTo(safeAreaLayoutGuide.snp.top).offset(CGFloat.topBarHeight)
        }
    }
}

private extension WalletContainerView {
    func setup() {
        backgroundColor = .Background.page

        addSubview(walletBalanceContainerView)

        walletBalanceContainerView.snp.makeConstraints { make in
            make.edges.equalTo(self)
        }
    }
}

private extension CGFloat {
    static let topBarHeight: CGFloat = 64
}
