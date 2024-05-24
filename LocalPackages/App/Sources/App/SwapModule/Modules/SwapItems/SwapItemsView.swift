import UIKit
import TKLocalize
import TKUIKit
import SnapKit

final class SwapItemsView: UIView {
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
  
  let switchButton = TKButton(configuration: .actionButtonConfiguration(category: .tertiary, size: .mediumMinus))

  let continueButton = TKButton(
    configuration: .actionButtonConfiguration(
      category: .primary,
      size: .large
    )
  )
  
  // swap info views
  var swapInfoViewHeightConstraint: Constraint!
  let rateLabel = UILabel()
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
  var isSwapInfoExpanded = false
  private lazy var swapRateView = {
    let stackView = UIStackView()
    stackView.distribution = .fill
    stackView.alignment = .center
    stackView.snp.makeConstraints { make in
      make.height.equalTo(36)
    }
    stackView.layoutMargins = .init(top: 0, left: 16, bottom: 0, right: 16)
    stackView.isLayoutMarginsRelativeArrangement = true
    rateLabel.font = TKTextStyle.body2.font
    rateLabel.textColor = .Text.secondary
    stackView.addArrangedSubview(rateLabel)
    stackView.addArrangedSubview(UIView())
    stackView.addArrangedSubview(arrowImageView)
    stackView.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(toggleInfoPressed)))
    return stackView
  }()
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
    stackView.addArrangedSubview(separatorViewGenerator())
    stackView.addArrangedSubview(swapRateView)
    stackView.addArrangedSubview(separatorViewGenerator())
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
    stackView.addArrangedSubview(continueButton)
    stackView.snp.makeConstraints { make in
      make.top.equalTo(scrollView).offset(CGFloat.contentVerticalPadding)
      make.left.right.bottom.equalTo(scrollView).priority(.high)
      make.width.equalTo(scrollView)
    }
    
    // switch (reverse) button
    stackView.addSubview(switchButton)
    switchButton.configuration = TKButton.Configuration(
      content: TKButton.Configuration.Content(icon: .TKUIKit.Icons.Size16.reverse),
      contentPadding: UIEdgeInsets(top: 14, left: 12, bottom: 14, right: 12),
      padding: .zero,
      iconTintColor: .Button.secondaryForeground,
      backgroundColors: [.normal: .Button.tertiaryBackground, .highlighted: .Button.tertiaryBackgroundHighlighted],
      cornerRadius: 20,
      action: nil
    )
    switchButton.snp.makeConstraints { make in
      make.centerY.equalTo(sellItemField.snp.bottom).inset(-4)
      make.right.equalTo(sellItemField.snp.right).inset(32)
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
    swapInfoViewContainer.snp.makeConstraints { make in
      self.swapInfoViewHeightConstraint = make.height.lessThanOrEqualTo(0).constraint
    }
    buyItemField.bottomStackView.addArrangedSubview(swapInfoViewContainer)
  }
}

private extension CGFloat {
  static let contentVerticalPadding: CGFloat = 16
}
