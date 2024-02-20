import UIKit

final class ToggleButton: UIButton {
  enum State {
    case selected
    case deselected
  }
  
  var didToggle: ((_ isSelected: Bool) -> Void)?
  
  private var backgroundColors = [State: UIColor]() {
    didSet {
      updateBackgroundColor()
    }
  }
  private var tintColors = [State: UIColor]() {
    didSet {
      updateTintColor()
    }
  }
  
  override var isSelected: Bool {
    didSet {
      guard isSelected != oldValue else { return }
      updateBackgroundColor()
      updateTintColor()
    }
  }
  
  override init(frame: CGRect) {
    super.init(frame: frame)
    setup()
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  func setBackgroundColor(_ color: UIColor,
                          for state: State) {
    backgroundColors[state] = color
  }
  
  func setTintColor(_ color: UIColor,
                    for state: State) {
    tintColors[state] = color
  }
}

private extension ToggleButton {
  func setup() {
    addTarget(self,
              action: #selector(didTapButton),
              for: .touchUpInside)
  }
  
  @objc
  func didTapButton() {
    isSelected.toggle()
    didToggle?(isSelected)
  }
  
  func updateBackgroundColor() {
    backgroundColor = isSelected ? backgroundColors[.selected] : backgroundColors[.deselected]
  }
  
  func updateTintColor() {
    tintColor = isSelected ? tintColors[.selected] : tintColors[.deselected]
  }
}
