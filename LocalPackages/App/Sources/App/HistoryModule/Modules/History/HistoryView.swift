import TKUIKit
import UIKit

final class HistoryView: UIView {
    let safeAreaBar = UIView()
    let navigationBar = TKNavigationBar()
    let listContainerView = UIView()
    let tabsView = TKTabsView()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

private extension HistoryView {
    func setup() {
        safeAreaBar.backgroundColor = .Background.page
        backgroundColor = .Background.page
        addSubview(listContainerView)
        addSubview(tabsView)
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
        tabsView.snp.makeConstraints { make in
            make.top.equalTo(navigationBar.snp.bottom)
            make.left.right.equalTo(self)
        }
        listContainerView.snp.makeConstraints { make in
            make.top.equalTo(self)
            make.left.right.bottom.equalTo(self)
        }
    }
}
