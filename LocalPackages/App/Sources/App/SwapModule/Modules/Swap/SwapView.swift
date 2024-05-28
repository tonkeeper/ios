import UIKit
import TKUIKit
import SnapKit

final class SwapView: UIView, ConfigurableView {
  
  enum DetailsPresentationState {
    case hidden
    case infoHidden
    case visible
  }
  
  private var detailsPresentationState: DetailsPresentationState = .hidden {
    didSet {
      guard detailsPresentationState != oldValue else { return }
      didUpdateDetailsPresentationState()
    }
  }
  
  var isDetailsHidden: Bool = true {
    didSet {
      guard isDetailsHidden != oldValue else { return }
      didUpdateIsDetailsHidden()
    }
  }
  
  let titleView = ModalTitleView()
  let scrollView = TKUIScrollView()
  
  let contentView = UIView()
  let swapSendContainerView = SwapSendContainerView()
  let swapRecieveContainerView = SwapRecieveContainerView()
  let swapDetailsContainerView = SwapDetailsContainerView()
  
  let swapSettingsButton: TKUIHeaderIconButton = {
    let button = TKUIHeaderIconButton()
    button.configure(
      model: TKUIHeaderButtonIconContentView.Model(
        image: .TKUIKit.Icons.Size16.sliders
      )
    )
    return button
  }()
  
  let swapButton = TKButton(
    configuration: .iconHeaderButtonConfiguration(
      contentPadding: .swapButtonContentPadding,
      padding: .swapButtonPadding
    )
  )
  
  let actionButton = TKButton(
    configuration: .actionButtonConfiguration(
      category: .primary,
      size: .large
    )
  )
  private let actionButtonContainer: TKPaddingContainerView = {
    let container = TKPaddingContainerView()
    container.padding = .actionButtonContainerPadding
    return container
  }()
  
  // MARK: - Init
  
  override init(frame: CGRect) {
    super.init(frame: frame)
    self.setup()
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  struct Model {
    struct SwapButton {
      let action: (() -> Void)?
    }
    
    let title: ModalTitleView.Model
    let swapButton: SwapButton
  }
  
  func configure(model: Model) {
    titleView.configure(model: model.title)
    swapButton.configuration.action = model.swapButton.action
  }
}

// MARK: - Setup

private extension SwapView {
  func setup() {
    scrollView.delaysContentTouches = false
    scrollView.showsVerticalScrollIndicator = false
    scrollView.showsHorizontalScrollIndicator = false
    
    contentView.layer.masksToBounds = true
    contentView.layer.cornerRadius = 16
    swapSendContainerView.layer.cornerRadius = 16
    swapRecieveContainerView.layer.cornerRadius = 16
    swapRecieveContainerView.layer.maskedCorners = [.layerMaxXMinYCorner, .layerMinXMinYCorner]
    
    swapSendContainerView.backgroundColor = .Background.content
    swapRecieveContainerView.backgroundColor = .Background.content
    swapDetailsContainerView.backgroundColor = .Background.content
    
    swapButton.configuration.cornerRadius = CGSize.swapButtonSize.inset(by: .swapButtonPadding).height/2
    swapButton.configuration.content.icon = .TKUIKit.Icons.Size16.swapVertical
    swapButton.configuration.backgroundColors = [
      .normal : .Button.tertiaryBackground,
      .highlighted : .Button.tertiaryBackgroundHighlighted
    ]
    
    swapDetailsContainerView.swapRateRow.addAction(UIAction(handler: { [weak self] _ in
      self?.didTapSwapRateRow()
    }), for: .touchUpInside)
    
    contentView.addSubview(swapSendContainerView)
    contentView.addSubview(swapRecieveContainerView)
    contentView.addSubview(swapDetailsContainerView)
    contentView.addSubview(swapButton)
    
    actionButtonContainer.setViews([actionButton])
    
    scrollView.addSubview(contentView)
    scrollView.addSubview(actionButtonContainer)
    addSubview(scrollView)
    
    setupConstraints()
  }
  
  func setupConstraints() {
    scrollView.snp.makeConstraints { make in
      make.edges.equalTo(self)
      make.width.equalTo(self)
    }
    
    scrollView.contentLayoutGuide.snp.makeConstraints { make in
      make.top.equalTo(contentView)
      make.width.equalTo(contentView)
      make.bottom.equalTo(actionButtonContainer)
    }
    
    contentView.snp.makeConstraints { make in
      make.top.equalTo(scrollView)
      make.width.equalTo(scrollView).inset(CGFloat.horizontalContentPadding)
      make.centerX.equalTo(scrollView)
      make.bottom.equalTo(swapRecieveContainerView)
    }
    
    swapSendContainerView.snp.makeConstraints { make in
      make.top.equalTo(contentView)
      make.left.right.equalTo(contentView)
      make.height.equalTo(CGFloat.swapContainerViewHeight)
    }
    
    swapRecieveContainerView.snp.makeConstraints { make in
      make.top.equalTo(swapSendContainerView.snp.bottom).offset(CGFloat.interContainerSpacing)
      make.left.right.equalTo(contentView)
      make.height.equalTo(CGFloat.swapContainerViewHeight)
    }
    
    swapDetailsContainerView.snp.makeConstraints { make in
      make.top.equalTo(swapRecieveContainerView.snp.bottom)
      make.left.right.equalTo(contentView)
    }
    
    swapButton.snp.makeConstraints { make in
      make.size.equalTo(CGSize.swapButtonSize)
      make.right.equalTo(contentView).inset(28)
      make.centerY.equalTo(swapSendContainerView.snp.bottom).offset(CGFloat.interContainerSpacing/2)
    }
    
    actionButtonContainer.snp.remakeConstraints { make in
      make.top.equalTo(contentView.snp.bottom)
      make.left.right.equalTo(contentView)
    }
  }
  
  func didTapSwapRateRow() {
    if detailsPresentationState == .visible {
      detailsPresentationState = .infoHidden
    } else if detailsPresentationState == .infoHidden {
      detailsPresentationState = .visible
    }
  }
  
  func didUpdateIsDetailsHidden() {
    if isDetailsHidden {
      detailsPresentationState = .hidden
    } else {
      detailsPresentationState = .visible
    }
  }
  
  func didUpdateDetailsPresentationState() {
    switch detailsPresentationState {
    case .hidden:
      hideDetails()
    case .infoHidden:
      hideInfo(animated: true)
    case .visible:
      showDetails(animated: true)
    }
  }
  
  func showDetails(animated: Bool = false) {
    prepareForAnimation()
    setContentViewBottomConstraint(equalTo: swapDetailsContainerView)
    
    if animated {
      UIView.animate(withDuration: 0.3, delay: 0, options: [.curveEaseInOut, .beginFromCurrentState]) {
        self.layoutIfNeeded()
      }
    }
  }
  
  func hideInfo(animated: Bool = false) {
    prepareForAnimation()
    setContentViewBottomConstraint(equalTo: swapDetailsContainerView.swapRateRow)
    
    if animated {
      UIView.animate(withDuration: 0.3, delay: 0, options: [.curveEaseInOut, .beginFromCurrentState]) {
        self.layoutIfNeeded()
      }
    }
  }
  
  func hideDetails(animated: Bool = false) {
    prepareForAnimation()
    setContentViewBottomConstraint(equalTo: swapRecieveContainerView)
    
    if animated {
      UIView.animate(withDuration: 0.3, delay: 0, options: [.curveEaseInOut, .beginFromCurrentState]) {
        self.layoutIfNeeded()
      }
    }
  }
  
  func prepareForAnimation() {
    contentView.layer.removeAllAnimations()
    actionButton.layer.removeAllAnimations()
    layoutIfNeeded()
  }
  
  func setContentViewBottomConstraint(equalTo bottomConstraintTarget: ConstraintRelatableTarget) {
    contentView.snp.remakeConstraints { make in
      make.top.centerX.equalTo(scrollView)
      make.width.equalTo(scrollView).inset(CGFloat.horizontalContentPadding)
      make.bottom.equalTo(bottomConstraintTarget)
    }
  }
}

private extension CGFloat {
  static let horizontalContentPadding: CGFloat = 16
  static let interContainerSpacing: CGFloat = 8
  static let swapContainerViewHeight: CGFloat = 108
}

private extension CGSize {
  static var swapButtonSize: CGSize {
    let iconSize = CGSize(width: 16, height: 16)
    let contentPadding = UIEdgeInsets.swapButtonContentPadding
    let padding = UIEdgeInsets.swapButtonPadding
    var sideSize = iconSize.width
    sideSize += contentPadding.left + contentPadding.right
    sideSize += padding.left + padding.right
    return CGSize(
      width: sideSize,
      height: sideSize
    )
  }
}

private extension UIEdgeInsets {
  static let swapButtonContentPadding: UIEdgeInsets = UIEdgeInsets(top: 12, left: 12, bottom: 12, right: 12)
  static let swapButtonPadding: UIEdgeInsets = UIEdgeInsets(top: 4, left: 4, bottom: 4, right: 4)
  static let actionButtonContainerPadding = UIEdgeInsets(top: 32, left: 0, bottom: 16, right: 0)
}
