import UIKit
import SnapKit

// MARK: - BarItemContainerView

final class ModalNavigationBarItemContainerView: UIView {
  
  enum ContentAlignment {
    case center
    case left
    case right
  }
  
  override var intrinsicContentSize: CGSize { getIntrinsicContentSize() }
  
  private let containedView: UIView
  private let height: CGFloat
  private let contentAlignment: ContentAlignment
  
  init(customView: UIView, height: CGFloat, contentAlignment: ContentAlignment = .center) {
    self.containedView = customView
    self.height = height
    self.contentAlignment = contentAlignment
    super.init(frame: .zero)
    self.setup()
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  private func getIntrinsicContentSize() -> CGSize {
    var width: CGFloat = containedView.bounds.width + .horizontalPadding * 2
    
    if width < .minimumBarItemWidth {
      let widthThatFits = containedView.sizeThatFits(bounds.size).width
      width = widthThatFits < .minimumBarItemWidth ? .minimumBarItemWidth : widthThatFits
    }
    
    return CGSize(width: width, height: height)
  }
}

// MARK: - Setup

private extension ModalNavigationBarItemContainerView {
  func setup() {
    addSubview(containedView)
    setupConstraints()
  }
  
  func setupConstraints() {
    containedView.snp.makeConstraints { make in
      make.centerY.equalTo(self)
      
      switch contentAlignment {
      case .center:
        make.centerX.equalTo(self)
      case .left:
        make.left.equalTo(self)
      case .right:
        make.right.equalTo(self)
      }
    }
  }
}

// MARK: - ModalNavigationBarView

open class ModalNavigationBarView: UIView {
  
  typealias ContentAlignment = ModalNavigationBarItemContainerView.ContentAlignment
  
  public enum ContainerAlignment {
    case center
    case top(_ padding: CGFloat)
    case bottom(_ padding: CGFloat)
  }
  
  static let defaultHeight: CGFloat = 64
  
  private let leftBarItemStack: UIStackView = .horizontalStack()
  private let centerBarItemStack: UIStackView = .horizontalStack()
  private let rightBarItemStack: UIStackView = .horizontalStack()
  
  override init(frame: CGRect) {
    super.init(frame: frame)
    self.setup()
  }
  
  required public init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  public struct BarItemConfiguration {
    let view: UIView
    let containerHeight: CGFloat
    let containerAlignment: ContainerAlignment
    let contentAlignment: ContentAlignment
    
    init(view: UIView,
         containerHeight: CGFloat = .barItemHeight,
         containerAlignment: ContainerAlignment = .center,
         contentAlignment: ContentAlignment = .center) {
      self.view = view
      self.containerHeight = containerHeight
      self.containerAlignment = containerAlignment
      self.contentAlignment = contentAlignment
    }
  }
  
  public func setupLeftBarItem(configuration: BarItemConfiguration) {
    setupBarItem(in: leftBarItemStack, configuration: configuration)
  }
  
  public func setupCenterBarItem(configuration: BarItemConfiguration) {
    setupBarItem(in: centerBarItemStack, configuration: configuration)
  }
  
  public func setupRightBarItem(configuration: BarItemConfiguration) {
    setupBarItem(in: rightBarItemStack, configuration: configuration)
  }
  
  private func setupBarItem(in barItemStack: UIStackView, configuration: BarItemConfiguration) {
    let customView = configuration.view
    let containerHeight = configuration.containerHeight
    let containerAlignment = configuration.containerAlignment
    let contentAlignment = configuration.contentAlignment
    
    barItemStack.arrangedSubviews.forEach { view in
      barItemStack.removeArrangedSubview(view)
      view.removeFromSuperview()
    }
    
    let containerView = ModalNavigationBarItemContainerView(
      customView: customView,
      height: containerHeight,
      contentAlignment: contentAlignment
    )
    
    barItemStack.isHidden = false
    barItemStack.addArrangedSubview(containerView)
    
    barItemStack.snp.makeConstraints { make in
      switch containerAlignment {
      case .center:
        make.centerY.equalTo(self)
      case .top(let padding):
        make.top.equalTo(self).offset(padding)
      case .bottom(let padding):
        make.bottom.equalTo(self).inset(padding)
      }
    }
  }
}

// MARK: - Setup

private extension ModalNavigationBarView {
  func setup() {
    backgroundColor = .Background.page
    
    leftBarItemStack.isHidden = true
    centerBarItemStack.isHidden = true
    rightBarItemStack.isHidden = true
    
    addSubview(leftBarItemStack)
    addSubview(centerBarItemStack)
    addSubview(rightBarItemStack)
    
    setupConstraints()
  }
  
  func setupConstraints() {
    leftBarItemStack.snp.makeConstraints { make in
      make.left.equalTo(self).offset(CGFloat.horizontalPadding)
    }
    
    centerBarItemStack.snp.makeConstraints { make in
      make.centerX.equalTo(self)
      make.width.lessThanOrEqualTo(CGFloat.centerBarItemStackMaximumWidth)
    }
    
    rightBarItemStack.snp.makeConstraints { make in
      make.right.equalTo(self).inset(CGFloat.horizontalPadding)
    }
  }
}

private extension UIStackView {
  static func horizontalStack() -> UIStackView {
    let stackView = UIStackView()
    stackView.axis = .horizontal
    return stackView
  }
}

private extension CGFloat {
  static let horizontalPadding: CGFloat = 8
  static let barItemHeight: CGFloat = 48
  static let minimumBarItemWidth: CGFloat = 48
  static let modalNavigationBarHeight: CGFloat = 64
  static let centerBarItemStackMaximumWidth: CGFloat = 200
}
