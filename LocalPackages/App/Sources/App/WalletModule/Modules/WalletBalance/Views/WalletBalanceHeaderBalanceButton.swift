import TKUIKit
import UIKit
import SnapKit

final class WalletBalanceHeaderBalanceButton: UIControl, ConfigurableView {
  enum State {
    case secure
    case unsecure
  }

  override var isHighlighted: Bool {
    didSet {
      alpha = isHighlighted ? 0.64 : 1
    }
  }
  
  private var tapHandler: (() -> Void)?

  private let balanceLabel = UILabel()
  private let secureView = UIView()
  private let stackView = UIStackView()
  
  override init(frame: CGRect) {
    super.init(frame: frame)
    setup()
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  override func layoutSubviews() {
    super.layoutSubviews()
    secureView.layer.cornerRadius = secureView.bounds.height/2
  }
  
  struct Model {
    let balance: String?
    let state: State
    let tapHandler: (() -> Void)?
  }
  
  func configure(model: Model) {
    balanceLabel.attributedText = model
      .balance?.withTextStyle(.balance, color: .Text.primary, alignment: .center)
    didUpdateSecureState(state: model.state)
    self.tapHandler = model.tapHandler
  }
  
  private func setup() {
    addAction(UIAction(handler: { [weak self] _ in
      self?.tapHandler?()
    }), for: .touchUpInside)
    
    balanceLabel.isUserInteractionEnabled = false
    secureView.isUserInteractionEnabled = false
    
    let secureLabel = UILabel()
    secureLabel.attributedText = "* * *".withTextStyle(.num2, color: .Text.primary)
    secureView.backgroundColor = .Button.secondaryBackground
    
    secureView.isHidden = true
    secureView.layer.cornerCurve = .continuous
    
    addSubview(balanceLabel)
    addSubview(secureView)
    secureView.addSubview(secureLabel)

    balanceLabel.snp.makeConstraints { make in
      make.centerX.centerY.equalTo(self)
    }
    
    secureView.snp.makeConstraints { make in
      make.centerX.centerY.equalTo(self)
    }
    
    secureLabel.snp.makeConstraints { make in
      make.left.right.equalTo(secureView).inset(16)
      make.top.equalTo(secureView).offset(5)
      make.bottom.equalTo(secureView).offset(5)
    }
  }
  
  private func didUpdateSecureState(state: State) {
    switch state {
    case .secure:
      balanceLabel.isHidden = true
      secureView.isHidden = false
    case .unsecure:
      balanceLabel.isHidden = false
      secureView.isHidden = true
    }
  }
}
