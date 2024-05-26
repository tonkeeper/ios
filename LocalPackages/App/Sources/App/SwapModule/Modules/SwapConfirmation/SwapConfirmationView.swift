import UIKit
import TKUIKit

final class SwapConfirmationView: UIView, ConfigurableView {
  
  let titleView = ModalTitleView()
  let scrollView = TKUIScrollView()
  
  let contentView = UIView()
  let swapSendContainerView = SwapSendContainerView()
  let swapRecieveContainerView = SwapRecieveContainerView()
  let swapInfoContainerView = SwapInfoContainerView()
  
  let cancelButton = TKButton(
    configuration: .actionButtonConfiguration(
      category: .primary,
      size: .large
    )
  )
  
  let confirmButton = TKButton(
    configuration: .actionButtonConfiguration(
      category: .primary,
      size: .large
    )
  )
  
  private let buttonsContainer: TKPaddingContainerView = {
    let container = TKPaddingContainerView()
    container.padding = UIEdgeInsets(
      top: 16,
      left: 16,
      bottom: 16,
      right: 16
    )
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
    struct Button {
      let title: String
      let isEnabled: Bool
      let isActivity: Bool
      let action: (() -> Void)?
    }
   
    let title: ModalTitleView.Model
    let sendContainer: SwapSendContainerView.Model
    let recieveContainer: SwapRecieveContainerView.Model
    let infoContainer: SwapInfoContainerView.Model
    let cancelButton: Button
    let confirmButton: Button
  }
  
  func configure(model: Model) {
    titleView.configure(model: model.title)
    swapSendContainerView.configure(model: model.sendContainer)
    swapRecieveContainerView.configure(model: model.recieveContainer)
    swapInfoContainerView.configure(model: model.infoContainer)
    
    cancelButton.configuration.content.title = .plainString(model.cancelButton.title)
    cancelButton.configuration.action = model.cancelButton.action
    
    confirmButton.configuration.content.title = .plainString(model.confirmButton.title)
    confirmButton.configuration.isEnabled = model.confirmButton.isEnabled
    confirmButton.configuration.showsLoader = model.confirmButton.isActivity
    confirmButton.configuration.action = model.confirmButton.action
  }
}

// MARK: - Setup

private extension SwapConfirmationView {
  func setup() {
    scrollView.delaysContentTouches = false
    scrollView.showsVerticalScrollIndicator = false
    scrollView.showsHorizontalScrollIndicator = false
    
    swapSendContainerView.isUserInteractionEnabled = false
    swapRecieveContainerView.isUserInteractionEnabled = false
    
    contentView.layer.masksToBounds = true
    contentView.layer.cornerRadius = 16
    swapSendContainerView.layer.cornerRadius = 16
    swapRecieveContainerView.layer.cornerRadius = 16
    swapRecieveContainerView.layer.maskedCorners = [.layerMaxXMinYCorner, .layerMinXMinYCorner]
    
    swapSendContainerView.backgroundColor = .Background.content
    swapRecieveContainerView.backgroundColor = .Background.content
    swapInfoContainerView.backgroundColor = .Background.content
    
    cancelButton.configuration.backgroundColors = [
      .normal : .Button.secondaryBackground,
      .highlighted : .Button.secondaryBackgroundHighlighted
    ]
    
    swapInfoContainerView.addTopDivider()
    
    buttonsContainer.setContainerAxis(.horizontal)
    buttonsContainer.setContainerDistribution(.fillEqually)
    buttonsContainer.setViews([cancelButton, confirmButton])
    
    contentView.addSubview(swapSendContainerView)
    contentView.addSubview(swapRecieveContainerView)
    contentView.addSubview(swapInfoContainerView)
    scrollView.addSubview(contentView)
    scrollView.addSubview(buttonsContainer)
    addSubview(scrollView)
    
    setupConstraints()
  }
  
  func setupConstraints() {
    scrollView.snp.makeConstraints { make in
      make.edges.equalTo(self)
      make.width.equalTo(self)
    }
    
    contentView.snp.makeConstraints { make in
      make.top.centerX.equalTo(scrollView)
      make.width.equalTo(scrollView).inset(CGFloat.horizontalContentPadding)
      make.bottom.equalTo(swapInfoContainerView)
    }
    
    swapSendContainerView.snp.makeConstraints { make in
      make.top.left.right.equalTo(contentView)
      make.height.equalTo(CGFloat.swapContainerViewHeight)
    }
    
    swapRecieveContainerView.snp.makeConstraints { make in
      make.top.equalTo(swapSendContainerView.snp.bottom).offset(CGFloat.interContainerSpacing)
      make.left.right.equalTo(contentView)
      make.height.equalTo(CGFloat.swapContainerViewHeight)
    }
    
    swapInfoContainerView.snp.makeConstraints { make in
      make.top.equalTo(swapRecieveContainerView.snp.bottom)
      make.left.right.equalTo(contentView)
    }
    
    buttonsContainer.snp.remakeConstraints { make in
      make.left.right.bottom.equalTo(self)
    }
    
    scrollView.contentLayoutGuide.snp.makeConstraints { make in
      make.bottom.equalTo(swapInfoContainerView).offset(CGFloat.horizontalContentPadding)
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
