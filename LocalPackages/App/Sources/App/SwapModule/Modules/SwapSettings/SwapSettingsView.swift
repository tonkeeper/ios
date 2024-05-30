import UIKit
import TKUIKit

final class SwapSettingsView: UIView, ConfigurableView {
  
  let titleView = ModalTitleView()
  let scrollView = TKUIScrollView()
  
  let slippageTitleDescription = SwapSettingsTitleDecriptionView()
  let slippageInputContainer = SlippageInputContainerView()
  let expertModeContainer = SwapSettingsExpertModeContainer()
  
  let contentView = UIView()
  private let contentStackView: UIStackView = {
    let stackView = UIStackView()
    stackView.axis = .vertical
    return stackView
  }()
  
  let saveButton = TKButton(
    configuration: .actionButtonConfiguration(
      category: .primary,
      size: .large
    )
  )
  let saveButtonContainer: TKPaddingContainerView = {
    let container = TKPaddingContainerView()
    container.padding = .saveButtonContainerPadding
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
      let action: (() -> Void)?
    }
   
    let title: ModalTitleView.Model
    let slippageTitleDescription: SwapSettingsTitleDecriptionView.Model
    let slippageInputContainer: SlippageInputContainerView.Model
    let expertModeContainer: SwapSettingsExpertModeContainer.Model
    let saveButton: Button
  }
  
  func configure(model: Model) {
    titleView.configure(model: model.title)
    slippageTitleDescription.configure(model: model.slippageTitleDescription)
    slippageInputContainer.configure(model: model.slippageInputContainer)
    expertModeContainer.configure(model: model.expertModeContainer)
    saveButton.configuration.content.title = .plainString(model.saveButton.title)
    saveButton.configuration.isEnabled = model.saveButton.isEnabled
    saveButton.configuration.action = model.saveButton.action
  }
}

// MARK: - Setup

private extension SwapSettingsView {
  func setup() {
    scrollView.delaysContentTouches = false
    scrollView.showsVerticalScrollIndicator = false
    scrollView.showsHorizontalScrollIndicator = false
    
    saveButtonContainer.setViews([saveButton])
    
    contentStackView.addArrangedSubview(slippageTitleDescription)
    contentStackView.addArrangedSubview(slippageInputContainer)
    contentStackView.setCustomSpacing(16, after: slippageInputContainer)
    contentStackView.addArrangedSubview(expertModeContainer)
    
    contentView.addSubview(contentStackView)
    scrollView.addSubview(contentView)
    
    addSubview(scrollView)
    addSubview(saveButtonContainer)
    
    setupConstraints()
  }
  
  func setupConstraints() {
    scrollView.snp.makeConstraints { make in
      make.edges.equalTo(self)
      make.width.equalTo(self)
    }
    
    contentView.snp.makeConstraints { make in
      make.left.right.bottom.equalTo(scrollView).priority(.high)
      make.top.width.equalTo(scrollView)
    }
    
    contentStackView.snp.makeConstraints { make in
      make.edges.equalTo(contentView).inset(UIEdgeInsets.contentStackViewPadding)
    }
    
    saveButtonContainer.snp.remakeConstraints { make in
      make.left.right.bottom.equalTo(self)
    }
  }
}

private extension CGFloat {
  static let verticalContentPadding: CGFloat = 16
}

private extension UIEdgeInsets {
  static let contentStackViewPadding = UIEdgeInsets(top: 0, left: 16, bottom: 0, right: 16)
  static let saveButtonContainerPadding = UIEdgeInsets(top: 16, left: 16, bottom: 16, right: 16)
}
