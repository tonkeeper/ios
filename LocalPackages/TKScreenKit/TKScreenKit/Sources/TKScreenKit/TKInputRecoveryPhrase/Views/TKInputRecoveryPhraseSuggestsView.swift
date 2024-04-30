import UIKit
import TKUIKit

final class TKInputRecoveryPhraseSuggestsView: UIView, ConfigurableView {
  private var buttons = [TKInputRecoveryPhraseSuggestsButton]()
  private var dividers = [UIView]()
  private let containerView = UIView()
  
  override init(frame: CGRect) {
    super.init(frame: frame)
    setup()
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  struct Model {
    let suggests: [TKInputRecoveryPhraseSuggestsButton.Model]
  }
  
  func configure(model: Model) {
    buttons.forEach { $0.removeFromSuperview() }
    buttons = []
    dividers.forEach { $0.removeFromSuperview() }
    dividers = []
    
    model.suggests.enumerated().forEach { index, buttonModel in
      let button = TKInputRecoveryPhraseSuggestsButton()
      button.configure(model: buttonModel)
      buttons.append(button)
      containerView.addSubview(button)
      
      if index < model.suggests.count - 1 {
        let divider = createDividerView()
        dividers.append(divider)
        containerView.addSubview(divider)
      }
    }
    setNeedsLayout()
  }
  
  override func layoutSubviews() {
    super.layoutSubviews()
    
    let sidePadding: CGFloat = 8
    let spacing: CGFloat = 8
    let dividerWidth: CGFloat = 1
    let dividerHeigth: CGFloat = 20
    let buttonSpacing: CGFloat = spacing * 2 + dividerWidth
    let availableWidth = bounds.width - sidePadding * 2
    let buttonWidth = (availableWidth - (buttonSpacing * CGFloat(buttons.count - 1)))/3.0
    let height: CGFloat = 36
    
    var buttonX: CGFloat = 0
    for button in buttons {
      button.frame = CGRect(x: buttonX, y: 0, width: buttonWidth, height: height)
      buttonX = button.frame.maxX + buttonSpacing
    }
    
    var dividerX: CGFloat = buttonWidth + spacing
    for divider in dividers {
      divider.frame = CGRect(x: dividerX, y: height/2 - dividerHeigth/2, width: dividerWidth, height: dividerHeigth)
      dividerX = divider.frame.maxX + spacing * 2 + buttonWidth
    }
    
    let containerWidth = buttons.last?.frame.maxX ?? 0
    containerView.frame = CGRect(x: bounds.width/2 - containerWidth/2, y: bounds.height/2 - height/2, width: containerWidth, height: height)
  }
}

private extension TKInputRecoveryPhraseSuggestsView {
  func setup() {
    backgroundColor = .Background.contentTint
    
    addSubview(containerView)
  }
  
  func createDividerView() -> UIView {
    let view = UIView()
    view.backgroundColor = .Icon.tertiary
    return view
  }
}
