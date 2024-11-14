import UIKit
import TKUIKit
import KeeperCore

final class TransactionConfirmationListContainerItemWalletValueView: UIView {
  struct Configuration: TKListContainerItemValue {
    func getView() -> UIView {
      let view = TransactionConfirmationListContainerItemWalletValueView()
      view.configuration = self
      return view
    }
    
    let wallet: Wallet
  }
  
  var configuration: Configuration? {
    didSet {
      didUpdateConfiguration()
      setNeedsLayout()
      invalidateIntrinsicContentSize()
    }
  }
  
  private let nameLabel = UILabel()
  private let iconLabel = UILabel()
  private let iconImageView = UIImageView()
  private let stackView = UIStackView()
  
  override init(frame: CGRect) {
    super.init(frame: frame)
    setup()
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  private func setup() {
    nameLabel.numberOfLines = 1
  
    stackView.axis = .horizontal
    stackView.alignment = .center
    stackView.distribution = .fill
    
    iconImageView.tintColor = .Icon.primary
    
    addSubview(stackView)
    stackView.addArrangedSubview(iconLabel)
    stackView.setCustomSpacing(4, after: iconLabel)
    stackView.addArrangedSubview(iconImageView)
    stackView.setCustomSpacing(4, after: iconImageView)
    stackView.addArrangedSubview(nameLabel)
    
    setContentHuggingPriority(.required, for: .horizontal)
    stackView.setContentHuggingPriority(.required, for: .horizontal)
    iconLabel.setContentHuggingPriority(.required, for: .horizontal)
    nameLabel.setContentHuggingPriority(.required, for: .horizontal)
    iconImageView.setContentHuggingPriority(.required, for: .horizontal)
    
    stackView.snp.makeConstraints { make in
      make.edges.equalTo(self)
    }
  }
  
  private func didUpdateConfiguration() {
    guard let configuration else {
      nameLabel.text = ""
      iconLabel.text = ""
      iconImageView.image = nil
      return
    }
    
    nameLabel.attributedText = configuration.wallet.label.withTextStyle(
      .label1,
      color: .Text.primary,
      alignment: .right,
      lineBreakMode: .byTruncatingTail
    )
    
    switch configuration.wallet.icon {
    case .emoji(let emoji):
      iconLabel.text = emoji
      iconLabel.isHidden = false
      iconImageView.image = nil
      iconImageView.isHidden = true
    case .icon(let icon):
      iconLabel.text = nil
      iconLabel.isHidden = true
      iconImageView.image = icon.image
      iconImageView.isHidden = false
    }
  }
}
