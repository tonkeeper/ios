import UIKit
import TKUIKit

final class StakeView: UIView, ConfigurableView {
  
  let titleView = ModalTitleView()
  let scrollView = TKUIScrollView()
  
  let amountInputView = StakeAmountInputView()
  let footerView = StakeFooterView()
  let selectedPoolContainer = StakePoolContainerView()
  
  private let contentStackView: UIStackView = {
    let stackView = UIStackView()
    stackView.axis = .vertical
    return stackView
  }()
  
  let stakeInfoButton: TKUIHeaderIconButton = {
    let button = TKUIHeaderIconButton()
    button.configure(
      model: TKUIHeaderButtonIconContentView.Model(
        image: .TKUIKit.Icons.Size16.informationCircle
      )
    )
    return button
  }()
  
  let continueButton = TKButton(
    configuration: .actionButtonConfiguration(
      category: .primary,
      size: .large
    )
  )
  let continueButtonContainer: TKPaddingContainerView = {
    let container = TKPaddingContainerView()
    container.padding = .continueButtonContainerPadding
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
      let action: (() -> Void)
    }
    
    let title: ModalTitleView.Model
    let input: StakeAmountInputView.Model
    let footer: StakeFooterView.Model
    let selectedPool: StakePoolContainerView.Model
    let button: Button
  }
  
  func configure(model: Model) {
    titleView.configure(model: model.title)
    amountInputView.configure(model: model.input)
    footerView.configure(model: model.footer)
    selectedPoolContainer.configure(model: model.selectedPool)
    continueButton.configuration.content.title = .plainString(model.button.title)
    continueButton.configuration.isEnabled = model.button.isEnabled
    continueButton.configuration.showsLoader = model.button.isActivity
    continueButton.configuration.action = model.button.action
  }
}

// MARK: - Setup

private extension StakeView {
  func setup() {
    contentStackView.addArrangedSubview(amountInputView)
    contentStackView.setCustomSpacing(16, after: amountInputView)
    contentStackView.addArrangedSubview(footerView)
    contentStackView.setCustomSpacing(32, after: footerView)
    contentStackView.addArrangedSubview(selectedPoolContainer)
    scrollView.addSubview(contentStackView)

    continueButtonContainer.setViews([continueButton])
    
    addSubview(scrollView)
    addSubview(continueButtonContainer)
    
    setupConstraints()
  }
  
  func setupConstraints() {
    scrollView.snp.makeConstraints { make in
      make.edges.equalTo(self)
      make.width.equalTo(self)
    }
    
    scrollView.contentLayoutGuide.snp.makeConstraints { make in
      make.top.bottom.width.equalTo(contentStackView)
    }
    
    contentStackView.snp.makeConstraints { make in
      make.top.centerX.equalTo(scrollView)
      make.width.equalTo(scrollView).inset(CGFloat.horizontalContentPadding)
    }
    
    continueButtonContainer.snp.makeConstraints { make in
      make.bottom.equalTo(self.safeAreaLayoutGuide)
      make.left.right.equalTo(self)
    }
  }
}

private extension CGFloat {
  static let horizontalContentPadding: CGFloat = 16
  static let verticalContentPadding: CGFloat = 16
}

private extension UIEdgeInsets {
  static let continueButtonContainerPadding = UIEdgeInsets(top: 16, left: 16, bottom: 16, right: 16)
}
