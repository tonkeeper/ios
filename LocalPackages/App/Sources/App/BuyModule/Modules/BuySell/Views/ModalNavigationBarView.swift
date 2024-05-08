import UIKit
import SnapKit

// MARK: - BarItemContainerView

final class ModalNavigationBarItemContainerView: UIView {
  override var intrinsicContentSize: CGSize { getIntrinsicContentSize() }
  
  private let containedView: UIView
  private let height: CGFloat
  
  init(customView: UIView, height: CGFloat) {
    self.containedView = customView
    self.height = height
    super.init(frame: .zero)
    self.setup()
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  private func setup() {
    addSubview(containedView)
    setupConstraints()
  }
  
  private func setupConstraints() {
    containedView.snp.makeConstraints { make in
      make.centerX.centerY.equalTo(self)
    }
  }
  
  private func getIntrinsicContentSize() -> CGSize {
    let width: CGFloat = containedView.bounds.width + .horizontalPadding * 2
    return CGSize(width: width, height: height)
  }
}

// MARK: - ModalNavigationBarView

open class ModalNavigationBarView: UIView {
  public enum ContainerAlignment {
    case center
    case top(_ padding: CGFloat)
    case bottom(_ padding: CGFloat)
  }
  
  static let defaultHeight: CGFloat = 64
  
  private let leftBarItemStack: UIStackView = {
    let stackView = UIStackView()
    stackView.axis = .horizontal
    return stackView
  }()
  
  private let centerBarItemStack: UIStackView = {
    let stackView = UIStackView()
    stackView.axis = .horizontal
    return stackView
  }()
  
  private let rightBarItemStack: UIStackView = {
    let stackView = UIStackView()
    stackView.axis = .horizontal
    return stackView
  }()
  
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
    
    init(view: UIView, containerHeight: CGFloat = 48, containerAlignment: ContainerAlignment = .center) {
      self.view = view
      self.containerHeight = containerHeight
      self.containerAlignment = containerAlignment
    }
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
    
    barItemStack.arrangedSubviews.forEach { view in
      barItemStack.removeArrangedSubview(view)
      view.removeFromSuperview()
    }
    
    let containerView = ModalNavigationBarItemContainerView(
      customView: customView,
      height: containerHeight
    )
    
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

private extension CGFloat {
  static let horizontalPadding: CGFloat = 8
  static let modalNavigationBarHeight: CGFloat = 64
  static let centerBarItemStackMaximumWidth: CGFloat = 200
}
