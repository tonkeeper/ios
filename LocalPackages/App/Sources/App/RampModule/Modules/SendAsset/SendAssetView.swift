import Kingfisher
import SnapKit
import TKUIKit
import UIKit

final class SendAssetView: TKView {
    let navigationBar = TKUINavigationBar()
    let titleView = TKUINavigationBarTitleView()
    let scrollView = UIScrollView()

    let warningView = SendAssetWarningView()
    let exchangeView = SendAssetExchangeView()
    let addressDetailsWrapperView = UIView()
    let addressView = SendAssetAddressView()
    let detailsView = SendAssetDetailsView()
    let addressShimmerView = SendAssetAddressShimmerView()
    let detailsShimmerView = SendAssetDetailsShimmerView()
    let disclaimerView = SendAssetDisclaimerView(verticalInsets: true)

    private let contentStackView: UIStackView = {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 16
        stack.alignment = .fill
        return stack
    }()

    private let addressDetailsStack: UIStackView = {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 8
        stack.alignment = .fill
        return stack
    }()

    private let addressDetailsShimmerStack: UIStackView = {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 8
        stack.alignment = .fill
        return stack
    }()

    let goToMainButton = TKButton(
        configuration: .actionButtonConfiguration(
            category: .secondary,
            size: .large
        )
    )
    private let goToMainButtonContainer = TKPaddingContainerView()

    override func setup() {
        super.setup()

        backgroundColor = .Background.page

        scrollView.showsVerticalScrollIndicator = false
        scrollView.contentInsetAdjustmentBehavior = .never

        navigationBar.centerView = titleView

        goToMainButtonContainer.setViews([goToMainButton])
        goToMainButtonContainer.padding.top = 16
        goToMainButtonContainer.padding.left = 16
        goToMainButtonContainer.padding.right = 16

        addSubview(scrollView)
        addSubview(navigationBar)
        addSubview(goToMainButtonContainer)

        scrollView.addSubview(contentStackView)

        addressDetailsStack.addArrangedSubview(addressView)
        addressDetailsStack.addArrangedSubview(detailsView)

        addressDetailsShimmerStack.addArrangedSubview(addressShimmerView)
        addressDetailsShimmerStack.addArrangedSubview(detailsShimmerView)

        addressDetailsWrapperView.addSubview(addressDetailsStack)
        addressDetailsWrapperView.addSubview(addressDetailsShimmerStack)

        contentStackView.addArrangedSubview(warningView)
        contentStackView.addArrangedSubview(exchangeView)
        contentStackView.addArrangedSubview(addressDetailsWrapperView)
        contentStackView.addArrangedSubview(disclaimerView)

        contentStackView.setCustomSpacing(.zero, after: addressDetailsWrapperView)

        addressDetailsShimmerStack.isHidden = true

        setupConstraints()
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        navigationBar.layoutIfNeeded()
        scrollView.contentInset.top = navigationBar.bounds.height
        scrollView.contentInset.bottom = goToMainButtonContainer.bounds.height
    }

    func setLoading(_ loading: Bool) {
        addressDetailsStack.isHidden = loading
        addressDetailsShimmerStack.isHidden = !loading
        loading ? addressShimmerView.startAnimation() : addressShimmerView.stopAnimation()
        loading ? detailsShimmerView.startAnimation() : detailsShimmerView.stopAnimation()
    }

    func setupConstraints() {
        navigationBar.snp.makeConstraints { make in
            make.top.leading.trailing.equalTo(self)
        }

        scrollView.snp.makeConstraints { make in
            make.edges.equalTo(self)
        }

        contentStackView.snp.makeConstraints { make in
            make.top.bottom.equalToSuperview()
            make.leading.trailing.equalToSuperview().inset(16)
            make.width.equalToSuperview().offset(-32)
        }

        goToMainButtonContainer.snp.makeConstraints { make in
            make.left.right.equalTo(self)
            make.bottom.equalTo(self)
        }

        addressDetailsStack.snp.makeConstraints { make in
            make.edges.equalTo(addressDetailsWrapperView)
        }

        addressDetailsShimmerStack.snp.makeConstraints { make in
            make.edges.equalTo(addressDetailsWrapperView)
        }
    }
}
