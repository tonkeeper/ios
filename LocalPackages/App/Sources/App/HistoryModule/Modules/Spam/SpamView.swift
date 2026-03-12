import TKUIKit
import UIKit

final class SpamView: UIView {
    let safeAreaBar = UIView()
    let navigationBar = TKUINavigationBar()
    let titleView = TKUINavigationBarTitleView()
    let listContainerView = UIView()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

private extension SpamView {
    func setup() {
        safeAreaBar.backgroundColor = .Background.page
        backgroundColor = .Background.page

        navigationBar.centerView = titleView

        addSubview(listContainerView)
        addSubview(navigationBar)
        addSubview(safeAreaBar)

        setupConstraints()
    }

    func setupConstraints() {
        safeAreaBar.snp.makeConstraints { make in
            make.top.left.right.equalTo(self)
            make.bottom.equalTo(safeAreaLayoutGuide.snp.top)
        }
        navigationBar.snp.makeConstraints { make in
            make.top.left.right.equalTo(self)
        }
        listContainerView.snp.makeConstraints { make in
            make.top.equalTo(self)
            make.left.right.bottom.equalTo(self)
        }
    }
}
