import UIKit
import TKUIKit
import SnapKit

final class WalletContainerTopBarView: UIView, ConfigurableView {
  
  var isSeparatorHidden = true {
    didSet { separatorView.isHidden = isSeparatorHidden }
  }
  
  private let separatorView: UIView = {
    let view = UIView()
    view.backgroundColor = .Separator.common
    view.isHidden = true
    return view
  }()
  
  private let contentContainerView = UIView()
  private let walletButton = TKButton()
  private let settingsButton = TKButton()
  
  override init(frame: CGRect) {
    super.init(frame: frame)
    setup()
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  struct Model {
    let walletButtonConfiguration: TKButton.Configuration
    let settingButtonConfiguration: TKButton.Configuration
  }
  
  func configure(model: Model) {
    walletButton.configuration = model.walletButtonConfiguration
    settingsButton.configuration = model.settingButtonConfiguration
  }
}

private extension WalletContainerTopBarView {
  func setup() {
    backgroundColor = .Background.page
    
    addSubview(contentContainerView)
    addSubview(separatorView)
    contentContainerView.addSubview(settingsButton)
    contentContainerView.addSubview(walletButton)
    
    setupConstraints()
  }
  
  func setupConstraints() {
    walletButton.snp.makeConstraints { make in
      make.top.equalTo(contentContainerView).inset(CGFloat.walletButtonTopInset)
      make.bottom.equalTo(contentContainerView).inset(CGFloat.walletButtonBottomInset)
      make.centerX.equalTo(contentContainerView)
      make.width.lessThanOrEqualTo(CGFloat.walletButtonMaxWidth)
    }
    
    contentContainerView.snp.makeConstraints { make in
      make.top.equalTo(safeAreaLayoutGuide)
      make.left.right.bottom.equalTo(self)
    }
    
    settingsButton.snp.makeConstraints { make in
      make.right.equalTo(contentContainerView).inset(CGFloat.settingsButtonRightInset)
      make.centerY.equalTo(contentContainerView)
    }
    
    separatorView.snp.makeConstraints { make in
      make.left.right.equalTo(self)
      make.bottom.equalTo(self)
      make.height.equalTo(TKUIKit.Constants.separatorWidth)
    }
  }
}

private extension CGFloat {
  static let walletButtonTopInset: CGFloat = 12
  static let walletButtonBottomInset: CGFloat = 12
  static let walletButtonMaxWidth: CGFloat = 200
  static let settingsButtonRightInset: CGFloat = 8
}
