import SnapKit
import UIKit

final class NetworkFeePickerUiView: UIView {
    let categoriesHostingView = SwiftUIHostingView()

    private let scrollContainerView = UIView()
    private var activeScrollView: UIScrollView?
    private var activeScrollViewHasRows = false
    private var categoriesHeightConstraint: Constraint?

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func setActiveScrollView(
        _ scrollView: UIScrollView,
        hasRows: Bool
    ) {
        if activeScrollView !== scrollView {
            activeScrollView?.removeFromSuperview()
            activeScrollView = scrollView
            scrollContainerView.addSubview(scrollView)
            scrollView.snp.makeConstraints { make in
                make.top.bottom.equalToSuperview()
                make.leading.trailing.equalToSuperview().inset(Layout.contentHorizontalInset)
            }
        }

        activeScrollViewHasRows = hasRows
        setNeedsLayout()
    }

    func calculateHeight(width: CGFloat) -> CGFloat {
        let categoriesHeight = updateCategoriesHeight(width: width)
        layoutIfNeeded()

        guard let activeScrollView else {
            return ceil(categoriesHeight)
        }

        activeScrollView.layoutIfNeeded()

        let contentHeight = activeScrollView.contentSize.height
            + activeScrollView.contentInset.top
            + activeScrollView.contentInset.bottom

        return ceil(categoriesHeight + contentHeight)
    }
}

private extension NetworkFeePickerUiView {
    enum Layout {
        static let contentHorizontalInset: CGFloat = 16
    }

    func setup() {
        backgroundColor = .clear

        addSubview(categoriesHostingView)
        addSubview(scrollContainerView)

        categoriesHostingView.snp.makeConstraints { make in
            make.top.leading.trailing.equalToSuperview()
            categoriesHeightConstraint = make.height.equalTo(0).constraint
        }

        scrollContainerView.snp.makeConstraints { make in
            make.top.equalTo(categoriesHostingView.snp.bottom)
            make.leading.trailing.bottom.equalToSuperview()
        }
    }

    func updateCategoriesHeight(width: CGFloat) -> CGFloat {
        let contentSize = categoriesHostingView.systemLayoutSizeFitting(
            CGSize(
                width: max(width, 1),
                height: UIView.layoutFittingCompressedSize.height
            ),
            withHorizontalFittingPriority: .required,
            verticalFittingPriority: .fittingSizeLevel
        )

        let height = ceil(contentSize.height)
        categoriesHeightConstraint?.update(offset: height)
        return height
    }
}
