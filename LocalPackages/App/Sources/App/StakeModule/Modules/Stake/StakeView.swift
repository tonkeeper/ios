import UIKit
import TKUIKit
import SnapKit

final class StakeView: UIView {
  
  // MARK: - UI
  
  let contentStackView: UIStackView = {
    let stackView = UIStackView()
    stackView.axis = .vertical
    return stackView
  }()
  
  // Input
  
  let stakeInputView = StakeInputView()
  
  let stakeInputContainer: TKPaddingContainerView = {
    let container = TKPaddingContainerView()
    container.padding = .inputPadding
    return container
  }()
  
  // Balance
  
  let balanceView = StakeAmountBalanceView()
  
  let balanceViewContainer: TKPaddingContainerView = {
    let container = TKPaddingContainerView()
    container.padding = .balancePadding
    return container
  }()
  
  // Stake List item
  
  let stakeListItemView = StakeListItemView()
  
  let stakingViewContainer: TKPaddingContainerView = {
    let container = TKPaddingContainerView()
    container.padding = .stakingPadding
    return container
  }()
  
  // Continue Button
  
  let continueButton = TKButton()
  let continueButtonContainer: TKPaddingContainerView = {
    let container = TKPaddingContainerView()
    container.backgroundView = TKGradientView(color: .Background.page, direction: .bottomToTop)
    container.padding = .continueButtonPadding
    return container
  }()
  
  // Properties
  
  var keyboardHeight: CGFloat = 0 {
    didSet {
      let continueButtonContainerYTranslation = min(0, -keyboardHeight)
      continueButtonContainer.snp.updateConstraints({ make in
        make.bottom.equalToSuperview().offset(continueButtonContainerYTranslation)
      })
    }
  }
  
  // MARK: - Init
  
  override init(frame: CGRect) {
    super.init(frame: frame)
    setup()
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  struct Model {
    
    struct Amount {
      struct Token {
        enum Image {
          case image(UIImage)
          case asyncImage(ImageDownloadTask)
        }
        let image: Image
        let title: String
      }
      
      let placeholder: String
      let text: String
      let fractionDigits: Int
      let token: Token
    }
    
    struct Button {
      let title: String
      let isEnabled: Bool
      let isActivity: Bool
      let action: (() -> Void)
    }
    
    struct Balance {
      enum Remaining {
        case insufficient
        case remaining(String)
      }
      let converted: String
      let remaining: Remaining
    }
    
    let balance: Balance
    let button: Button
    let amount: Amount?
  }
  
  func configure(model: Model) {
    var continueButtonConfiguration = TKButton.Configuration.actionButtonConfiguration(
      category: .primary,
      size: .large
    )
    continueButtonConfiguration.content.title = .plainString(model.button.title)
    continueButtonConfiguration.isEnabled = model.button.isEnabled
    continueButtonConfiguration.action = model.button.action
    continueButton.configuration = continueButtonConfiguration
    
    switch model.balance.remaining {
    case .insufficient:
      balanceView.availableLabel.isHidden = true
      balanceView.insufficientLabel.isHidden = false
    case .remaining(let value):
      balanceView.availableLabel.isHidden = false
      balanceView.insufficientLabel.isHidden = true
      
      balanceView.convertedValue = value
    }
    
    stakeInputView.textInputControl.text = model.amount?.text ?? "0"
    // stakeInputView.stakeInputBalanceView.configure(amount: <#T##String#>, isNeedIcon: <#T##Bool#>)
  }
  
}

private extension StakeView {
  func setup() {
    backgroundColor = .Background.page
    
    addSubview(contentStackView)
    addSubview(continueButtonContainer)
    
    contentStackView.addArrangedSubview(stakeInputContainer)
    stakeInputContainer.setViews([stakeInputView])
    
    var configuration = TKButton.Configuration.titleHeaderButtonConfiguration(category: .tertiary)
    configuration.content.title = .plainString("MAX")
    balanceView.maxButton.configuration = configuration
    
    contentStackView.addArrangedSubview(balanceViewContainer)
    balanceViewContainer.setViews([balanceView])
    
    contentStackView.addArrangedSubview(stakingViewContainer)
    contentStackView.addArrangedSubview(UIView())
    
    stakingViewContainer.setViews([stakeListItemView])
    continueButtonContainer.setViews([continueButton])
    setupConstraints()
  }
  
  func setupConstraints() {
    contentStackView.snp.makeConstraints { make in
      make.top.equalToSuperview().inset(UIEdgeInsets.contentPadding.top)
      make.leading.trailing.equalToSuperview()
      make.bottom.equalToSuperview()
    }
    
    continueButtonContainer.snp.makeConstraints { make in
      make.bottom.equalToSuperview()
      make.leading.equalToSuperview()
      make.trailing.equalToSuperview()
    }
    
    stakeInputView.snp.makeConstraints { make in
      make.height.equalTo(168) // TODO: @Semyon сделать динамику
    }
  }
}

private extension UIEdgeInsets {
  static let contentPadding = UIEdgeInsets(
    top: 64,
    left: 0,
    bottom: 0,
    right: 0
  )
  
  static let inputPadding = UIEdgeInsets(
    top: 0,
    left: 16,
    bottom: 16,
    right: 16
  )
  
  static let balancePadding = UIEdgeInsets(
    top: 0,
    left: 16,
    bottom: 16,
    right: 16
  )
  
  static let stakingPadding = UIEdgeInsets(
    top: 16,
    left: 16,
    bottom: 0,
    right: 16
  )
  
  static let continueButtonPadding = UIEdgeInsets(
    top: 16,
    left: 16,
    bottom: 16,
    right: 16
  )
}
