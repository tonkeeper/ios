import SnapKit
import SwiftUI
import TKUIKit
import UIKit

/// `SwiftUIHostingView` reports no intrinsic height, so inside the screen's stack view a block is sized explicitly.
final class StakingBalanceDetailsHostingBlockView: UIView {
    private let hostingView = SwiftUIHostingView()
    private var heightConstraint: Constraint?
    private var measuredWidth: CGFloat = 0

    override init(frame: CGRect) {
        super.init(frame: frame)
        addSubview(hostingView)
        hostingView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
            heightConstraint = make.height.equalTo(0).constraint
        }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func setContent<Content: View>(@ViewBuilder _ content: () -> Content) {
        hostingView.setContent(content)
        updateHeight()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        guard bounds.width != measuredWidth else { return }
        updateHeight()
    }

    private func updateHeight() {
        let width = bounds.width > 0 ? bounds.width : UIScreen.main.bounds.width
        measuredWidth = bounds.width
        let size = hostingView.systemLayoutSizeFitting(
            CGSize(width: width, height: UIView.layoutFittingCompressedSize.height),
            withHorizontalFittingPriority: .required,
            verticalFittingPriority: .fittingSizeLevel
        )
        heightConstraint?.update(offset: size.height)
    }
}
