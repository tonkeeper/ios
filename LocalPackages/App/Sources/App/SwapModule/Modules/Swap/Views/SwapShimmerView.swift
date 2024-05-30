import UIKit
import TKUIKit
import SnapKit

// MARK: - SwapShimmerView

final class SwapShimmerView: UIView {
  
  private let sendContainer = UIView.createSwapContainer()
  private let sendInputShimmerView = SwapInputShimmerView()
  
  private let recieveContainer = UIView.createSwapContainer()
  private let recieveInputShimmerView = SwapInputShimmerView()
  
  private let swapButtonBackgroundView = UIView()
  private let swapButtonShimmerView = TKShimmerView()
  
  private let actionButtonBackgroundView = UIView()
  private let actionButtonShimmerView = TKShimmerView()
  
  private let contentStackView: UIStackView = {
    let stackView = UIStackView()
    stackView.axis = .vertical
    return stackView
  }()
  
  override init(frame: CGRect) {
    super.init(frame: frame)
    self.setup()
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  func startAnimation() {
    sendInputShimmerView.startAnimation()
    recieveInputShimmerView.startAnimation()
    swapButtonShimmerView.startAnimation()
    actionButtonShimmerView.startAnimation()
  }
  
  private func setup() {
    swapButtonBackgroundView.layer.masksToBounds = true
    actionButtonBackgroundView.layer.masksToBounds = true
    swapButtonBackgroundView.layer.cornerRadius = 20
    actionButtonBackgroundView.layer.cornerRadius = 16
    actionButtonShimmerView.cornerRadiusRule = .fixed(16)
    
    backgroundColor = .Background.page
    swapButtonBackgroundView.backgroundColor = .Button.secondaryBackground
    actionButtonBackgroundView.backgroundColor = .Button.secondaryBackground.withAlphaComponent(0.48)
    
    
    sendContainer.addSubview(sendInputShimmerView)
    recieveContainer.addSubview(recieveInputShimmerView)
    
    contentStackView.addArrangedSubview(sendContainer)
    contentStackView.setCustomSpacing(8, after: sendContainer)
    contentStackView.addArrangedSubview(recieveContainer)
    contentStackView.setCustomSpacing(32, after: recieveContainer)
    contentStackView.addArrangedSubview(actionButtonBackgroundView)
    
    addSubview(contentStackView)
    addSubview(swapButtonBackgroundView)
    addSubview(swapButtonShimmerView)
    addSubview(actionButtonShimmerView)
    
    setupConstraints()
  }
  
  private func setupConstraints() {
    contentStackView.snp.makeConstraints { make in
      make.top.left.right.equalTo(self)
    }
    
    sendInputShimmerView.snp.makeConstraints { make in
      make.top.left.right.equalTo(sendContainer)
      make.height.equalTo(92)
    }
    
    recieveInputShimmerView.snp.makeConstraints { make in
      make.top.equalTo(recieveContainer).offset(12)
      make.left.right.equalTo(recieveContainer)
      make.height.equalTo(92)
    }
    
    swapButtonBackgroundView.snp.makeConstraints { make in
      make.width.height.equalTo(40)
      make.right.equalTo(contentStackView).inset(32)
      make.centerY.equalTo(sendContainer.snp.bottom).offset(4)
    }
    
    actionButtonBackgroundView.snp.makeConstraints { make in
      make.height.equalTo(56)
    }
    
    swapButtonShimmerView.snp.makeConstraints { make in
      make.edges.equalTo(swapButtonBackgroundView)
    }
    
    actionButtonShimmerView.snp.makeConstraints { make in
      make.edges.equalTo(actionButtonBackgroundView)
    }
  }
}

private extension UIView {
  static func createSwapContainer() -> UIView {
    let view = UIView()
    view.backgroundColor = .Background.content.withAlphaComponent(0.48)
    view.layer.cornerRadius = 16
    view.layer.masksToBounds = true
    view.snp.makeConstraints { make in
      make.height.equalTo(108)
    }
    return view
  }
}

// MARK: - SwapInputShimmerView

private final class SwapInputShimmerView: UIView {
  
  private let titleShimmerView = TKShimmerView()
  private let tokenButtonShimmerView = TKShimmerView()
  private let balanceTitleShimmerView = TKShimmerView()
  private let amountInputShimmerView = TKShimmerView()

  override init(frame: CGRect) {
    super.init(frame: frame)
    self.setup()
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  func startAnimation() {
    titleShimmerView.startAnimation()
    tokenButtonShimmerView.startAnimation()
    balanceTitleShimmerView.startAnimation()
    amountInputShimmerView.startAnimation()
  }
  
  private func setup() {
    addSubview(titleShimmerView)
    addSubview(tokenButtonShimmerView)
    addSubview(balanceTitleShimmerView)
    addSubview(amountInputShimmerView)
    
    setupConstraints()
  }
  
  private func setupConstraints() {
    titleShimmerView.snp.makeConstraints { make in
      make.top.equalTo(self).offset(16)
      make.left.equalTo(self).offset(16)
      make.width.equalTo(CGFloat.random(in: 37...50))
      make.height.equalTo(20)
    }
    
    tokenButtonShimmerView.snp.makeConstraints { make in
      make.top.equalTo(titleShimmerView.snp.bottom).offset(8)
      make.left.equalTo(titleShimmerView)
      make.width.equalTo(CGFloat.random(in: 88...101))
      make.height.equalTo(36)
    }
    
    balanceTitleShimmerView.snp.makeConstraints { make in
      make.top.equalTo(titleShimmerView)
      make.right.equalTo(self).inset(16)
      make.width.equalTo(CGFloat.random(in: 60...100))
      make.height.equalTo(20)
    }
    
    amountInputShimmerView.snp.makeConstraints { make in
      make.top.equalTo(tokenButtonShimmerView)
      make.right.equalTo(self).inset(16)
      make.width.equalTo(CGFloat.random(in: 100...150))
      make.height.equalTo(36)
    }
  }
}
