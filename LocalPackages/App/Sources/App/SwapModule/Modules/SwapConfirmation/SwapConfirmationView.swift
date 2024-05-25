import UIKit
import TKLocalize
import TKUIKit
import SnapKit

final class SwapConfirmationView: UIView {
  let scrollView = TKUIScrollView()
  let stackView: UIStackView = {
    let stackView = UIStackView()
    stackView.axis = .vertical
    stackView.spacing = .contentVerticalPadding
    stackView.isLayoutMarginsRelativeArrangement = true
    stackView.directionalLayoutMargins = NSDirectionalEdgeInsets(
      top: 0,
      leading: 16,
      bottom: 16,
      trailing: 16
    )
    return stackView
  }()
  
  let sellItemField = TKSwapTokenField(mode: .sell)
  let buyItemField = TKSwapTokenField(mode: .buy)

  let cancelButton = TKButton(
    configuration: .actionButtonConfiguration(
      category: .secondary,
      size: .large
    )
  )
  
  let continueButton = TKButton(
    configuration: .actionButtonConfiguration(
      category: .primary,
      size: .large
    )
  )
  
  // swap info views
  var swapInfoViewHeightConstraint: Constraint!
  //let rateLabel = UILabel()
  let priceImpactLabel = UILabel()
  let minimumReceivedLabel = UILabel()
  let liquidityProviderFeeLabel = UILabel()
  let blockchainFeeLabel = UILabel()
  let routeLabel = UILabel()
  let providerLabel = UILabel()
  let arrowImageView = {
    let iv = UIImageView(image: .TKUIKit.Icons.Size16.chevronDown)
    iv.tintColor = .Text.secondary
    return iv
  }()
  var isSwapInfoExpanded = true
  private func itemRowGenerator(title: String, label: UILabel, info: String? = nil) -> UIStackView {
    let stackView = UIStackView()
    stackView.snp.makeConstraints { make in
      make.height.equalTo(36)
    }
    stackView.alignment = .center
    stackView.distribution = .fill
    stackView.layoutMargins = .init(top: 0, left: 16, bottom: 0, right: 16)
    stackView.isLayoutMarginsRelativeArrangement = true
    let titleLabel = UILabel()
    titleLabel.font = TKTextStyle.body2.font
    titleLabel.textColor = .Text.secondary
    titleLabel.text = title
    label.font = TKTextStyle.body2.font
    label.textColor = .Text.primary
    titleLabel.setContentHuggingPriority(.required, for: .horizontal)
    label.setContentHuggingPriority(.required, for: .horizontal)
    stackView.addArrangedSubview(titleLabel)
    if let info {
      let infoImageView = UIImageView(image: .TKUIKit.Icons.Size16.info)
      infoImageView.tintColor = .Text.secondary
      stackView.setCustomSpacing(5, after: titleLabel)
      stackView.addArrangedSubview(infoImageView)
      stackView.isUserInteractionEnabled = true
      stackView.addGestureRecognizer(TKClosureTapGestureRecognizer {
        ToastPresenter.showToast(configuration: ToastPresenter.Configuration(title: info,
                                                                             backgroundColor: .Background.contentTint,
                                                                             foregroundColor: .Text.primary,
                                                                             dismissRule: .duration(5),
                                                                             alignment: .left,
                                                                             position: .bottom))
      })
    }
    stackView.addArrangedSubview(UIView())
    stackView.addArrangedSubview(label)
    return stackView
  }
  private lazy var swapInfoView = {
    let stackView = UIStackView()
    stackView.axis = .vertical
    stackView.alignment = .fill
    let separatorViewGenerator = {
      let view = TKSeparatorView()
      view.color = .Separator.common
      return view
    }
    stackView.addArrangedSubview(
      itemRowGenerator(title: TKLocales.Swap.priceImpact, label: priceImpactLabel, info: TKLocales.Swap.priceImpactInfo)
    )
    stackView.addArrangedSubview(
      itemRowGenerator(title: TKLocales.Swap.minimumReceived, label: minimumReceivedLabel, info: TKLocales.Swap.minimumReceivedInfo)
    )
    stackView.addArrangedSubview(
      itemRowGenerator(title: TKLocales.Swap.liquidityProviderFee, label: liquidityProviderFeeLabel, info: TKLocales.Swap.liquidityProviderFeeInfo)
    )
    stackView.addArrangedSubview(itemRowGenerator(title: TKLocales.Swap.blockchainFee, label: blockchainFeeLabel))
    stackView.addArrangedSubview(itemRowGenerator(title: TKLocales.Swap.route, label: routeLabel))
    stackView.addArrangedSubview(itemRowGenerator(title: TKLocales.Swap.provider, label: providerLabel))
    return stackView
  }()
  
  private var buttonsStackView: UIStackView {
    let stackView = UIStackView()
    stackView.spacing = 16
    stackView.distribution = .fillEqually
    stackView.addArrangedSubview(cancelButton)
    stackView.addArrangedSubview(continueButton)
    return stackView
  }

  override init(frame: CGRect) {
    super.init(frame: frame)
    setup()
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  @objc func toggleInfoPressed() {
    endEditing(true)
    isSwapInfoExpanded = !isSwapInfoExpanded
    if swapInfoViewHeightConstraint.layoutConstraints.first?.constant ?? 0 > 0 {
      UIView.animate(withDuration: 0.2) {
        self.arrowImageView.transform = .init(rotationAngle: self.isSwapInfoExpanded ? .pi : 0)
        self.swapInfoViewHeightConstraint.update(offset: self.isSwapInfoExpanded ? 1000 : 36)
        self.layoutIfNeeded()
      }
    }
  }
  
  private func setup() {
    addSubview(scrollView)
    scrollView.addSubview(stackView)
    scrollView.snp.makeConstraints { make in
      make.edges.equalTo(self)
      make.width.equalTo(self)
    }
    scrollView.keyboardDismissMode = .onDrag
    
    stackView.addArrangedSubview(sellItemField)
    stackView.addArrangedSubview(buyItemField)
    stackView.addArrangedSubview(buttonsStackView)
    stackView.snp.makeConstraints { make in
      make.top.equalTo(scrollView).offset(CGFloat.contentVerticalPadding)
      make.left.right.bottom.equalTo(scrollView).priority(.high)
      make.width.equalTo(scrollView)
    }
    
    // swap info view
    let swapInfoViewContainer = UIView()
    swapInfoViewContainer.addSubview(swapInfoView)
    swapInfoViewContainer.layer.masksToBounds = true
    swapInfoView.snp.makeConstraints { make in
      make.horizontalEdges.equalTo(swapInfoViewContainer)
      make.top.equalTo(swapInfoViewContainer)
      make.bottom.equalTo(swapInfoViewContainer).priority(.low)
    }
    arrowImageView.transform = .init(rotationAngle: .pi)
    swapInfoViewContainer.snp.makeConstraints { make in
      self.swapInfoViewHeightConstraint = make.height.lessThanOrEqualTo(1000).constraint
    }
    buyItemField.bottomStackView.addArrangedSubview(swapInfoViewContainer)
  }
}

private extension CGFloat {
  static let contentVerticalPadding: CGFloat = 16
}
