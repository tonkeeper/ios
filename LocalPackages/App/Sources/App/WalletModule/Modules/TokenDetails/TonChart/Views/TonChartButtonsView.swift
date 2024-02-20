import UIKit
import TKUIKit

final class TonChartButtonsView: UIView, ConfigurableView {
  
  var didTapButton: ((_ index: Int) -> Void)?
  
  private let stackView: UIStackView = {
    let stackView = UIStackView()
    stackView.axis = .horizontal
    stackView.distribution = .fillEqually
    return stackView
  }()
  private var buttons = [TonChartButton]()
  
  // MARK: - Init
  
  override init(frame: CGRect) {
    super.init(frame: frame)
    setup()
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  // MARK: - ConfigurableView
  
  struct Model {
    struct Button {
      let model: TonChartButton.Model
      let action: () -> Void
    }
    let buttons: [Button]
  }
  
  func configure(model: Model) {
    buttons.forEach { $0.removeFromSuperview() }
    buttons = []
    model.buttons.forEach { buttonModel in
      let button = TonChartButton()
      button.configure(model: buttonModel.model)
      button.setTapAction(buttonModel.action)
      buttons.append(button)
      stackView.addArrangedSubview(button)
    }
  }
  
  // MARK: - Select
  
  func selectButton(at index: Int) {
    buttons.enumerated().forEach { buttonIndex, button in
      button.isSelected = buttonIndex == index
    }
  }
}

private extension TonChartButtonsView {
  func setup() {
    addSubview(stackView)
    stackView.translatesAutoresizingMaskIntoConstraints = false
    NSLayoutConstraint.activate([
      stackView.topAnchor.constraint(equalTo: topAnchor, constant: .verticalSpace),
      stackView.leftAnchor.constraint(equalTo: leftAnchor, constant: .horizontalSpace),
      stackView.rightAnchor.constraint(equalTo: rightAnchor, constant: -.horizontalSpace)
        .withPriority(.defaultHigh),
      stackView.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -.verticalSpace)
        .withPriority(.defaultHigh),
      stackView.heightAnchor.constraint(equalToConstant: .buttonsHeight)
    ])
  }
}

private extension CGFloat {
  static let buttonsHeight: CGFloat = 36
  static let horizontalSpace: CGFloat = 27
  static let verticalSpace: CGFloat = 24
}
