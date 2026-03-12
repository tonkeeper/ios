import TKUIKit
import UIKit

public final class ReceiveView: UIView {
    let navigationBar = TKUINavigationBar()
    let segmentedControl = TKSegmentedControl()
    let pageContainer = UIView()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

private extension ReceiveView {
    func setup() {
        backgroundColor = .Background.page

        segmentedControl.selectionColor = .Accent.blue

        addSubview(navigationBar)
        addSubview(pageContainer)

        setupConstraints()
    }

    func setupConstraints() {
        navigationBar.snp.makeConstraints { make in
            make.top.left.right.equalTo(self)
        }
        pageContainer.snp.makeConstraints { make in
            make.top.equalTo(navigationBar.snp.bottom)
            make.left.bottom.right.equalTo(self)
        }
    }
}
