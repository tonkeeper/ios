import UIKit
import TKUIKit

final class SwapSettingsExpertModeContainer: UIView, ConfigurableView {
  
  let titleDescriptionView = SwapSettingsTitleDecriptionView(padding: .zero)
  let switchView = UISwitch()
  
  private let contentStackView: UIStackView = {
    let stackView = UIStackView()
    stackView.axis = .horizontal
    stackView.alignment = .center
    stackView.spacing = 16
    return stackView
  }()
  
  override init(frame: CGRect) {
    super.init(frame: frame)
    self.setup()
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  struct Model {
    struct Switcher {
      let isOn: Bool
      let action: ((Bool) -> Void)?
    }
    
    let titleDescription: SwapSettingsTitleDecriptionView.Model
    let switcher: Switcher
  }
  
  func configure(model: Model) {
    titleDescriptionView.configure(model: model.titleDescription)
    switchView.isOn = model.switcher.isOn
    switchView.addAction(UIAction(handler: { [weak self] _ in
      guard let self else { return }
      model.switcher.action?(self.switchView.isOn)
    }), for: .valueChanged)
    
    invalidateIntrinsicContentSize()
  }
}

private extension SwapSettingsExpertModeContainer {
  func setup() {
    layer.cornerRadius = 16
    backgroundColor = .Background.content
    switchView.onTintColor = .Button.primaryBackground
    
    contentStackView.addArrangedSubview(titleDescriptionView)
    contentStackView.addArrangedSubview(switchView)
    addSubview(contentStackView)
    
    setupConstraints()
  }
  
  func setupConstraints() {
    contentStackView.snp.makeConstraints { make in
      make.edges.equalTo(self).inset(UIEdgeInsets.contentStackViewPadding)
    }
  }
}

private extension UIEdgeInsets {
  static let contentStackViewPadding = UIEdgeInsets(top: 16, left: 16, bottom: 16, right: 16)
}
