import TKUIKit
import UIKit

final class CollectiblesView: UIView {
    let safeAreaBar = UIView()
    let navigationBar = CollectiblesNavigationBar()
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

private extension CollectiblesView {
    func setup() {
        safeAreaBar.backgroundColor = .Background.page
        backgroundColor = .Background.page
        addSubview(listContainerView)
        addSubview(navigationBar)
        addSubview(safeAreaBar)

        if UIApplication.useSystemBarsAppearance {
            navigationBar.isHidden = true
            safeAreaBar.isHidden = true
        }

        setupConstraints()
    }

    func setupConstraints() {
        safeAreaBar.snp.makeConstraints { make in
            make.top.left.right.equalTo(self)
            make.bottom.equalTo(safeAreaLayoutGuide.snp.top)
        }
        navigationBar.snp.makeConstraints { make in
            make.top.equalTo(safeAreaLayoutGuide.snp.top)
            make.left.right.equalTo(self)
        }
        listContainerView.snp.makeConstraints { make in
            make.top.equalTo(self)
            make.left.right.bottom.equalTo(self)
        }
    }
}
