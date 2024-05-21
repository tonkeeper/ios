import UIKit
import TKUIKit

final class SwapView: UIView {
  
  var isDetailsHidden: Bool = true {
    didSet {
      guard isDetailsHidden != oldValue else { return }
      didUpdateDetailsContainerState()
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
  
  // MARK: - Init
  
  override init(frame: CGRect) {
    super.init(frame: frame)
    self.setup()
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  func showDetails(animated: Bool = false) {
    layoutIfNeeded()
    
    contentView.snp.remakeConstraints { make in
      make.top.equalTo(scrollView)
      make.width.equalTo(scrollView).inset(CGFloat.horizontalContentPadding)
      make.centerX.equalTo(scrollView)
      make.bottom.equalTo(swapDetailsContainerView)
    }
    
    if animated {
      UIView.animate(withDuration: 0.3, delay: 0, options: [.curveEaseInOut, .beginFromCurrentState]) {
        self.layoutIfNeeded()
      }
    }
  }
  
  func hideDetails(animated: Bool = false) {
    layoutIfNeeded()
    
    contentView.snp.remakeConstraints { make in
      make.top.equalTo(scrollView)
      make.width.equalTo(scrollView).inset(CGFloat.horizontalContentPadding)
      make.centerX.equalTo(scrollView)
      make.bottom.equalTo(swapRecieveContainerView)
    }
    
    if animated {
      UIView.animate(withDuration: 0.3, delay: 0, options: [.curveEaseInOut, .beginFromCurrentState]) {
        self.layoutIfNeeded()
      }
    }
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
    
    contentView.addSubview(swapSendContainerView)
    contentView.addSubview(swapRecieveContainerView)
    contentView.addSubview(swapDetailsContainerView)
    contentView.addSubview(swapButton)
    
    scrollView.addSubview(contentView)
    scrollView.addSubview(actionButton)
    addSubview(scrollView)
    
    setupConstraints()
  }
  
  func setupConstraints() {
    scrollView.snp.makeConstraints { make in
      make.edges.equalTo(self)
      make.width.equalTo(self)
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
    
    actionButton.snp.remakeConstraints { make in
      make.top.equalTo(contentView.snp.bottom).offset(32)
      make.left.right.equalTo(contentView)
    }
    
    scrollView.contentLayoutGuide.snp.makeConstraints { make in
      make.bottom.equalTo(actionButton).offset(CGFloat.horizontalContentPadding)
    }
  }
  
  func didUpdateDetailsContainerState() {
    if isDetailsHidden {
      hideDetails()
    } else {
      showDetails(animated: true)
    }
  }
}

private extension CGFloat {
  static let horizontalContentPadding: CGFloat = 16
  static let interContainerSpacing: CGFloat = 8
  static let swapContainerViewHeight: CGFloat = 108
  static var contentContainerHeight: CGFloat {
    2 * .swapContainerViewHeight + .interContainerSpacing
  }
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
}
