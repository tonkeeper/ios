import UIKit

public final class TKUIListItemRadioButtonAccessoryView: UIView, TKConfigurableView {
  public typealias RadioButtonHandlerClosure = ((Bool) -> Void)
  
  private let radioButton = RadioButton()
  
  public override init(frame: CGRect) {
    super.init(frame: frame)
    setup()
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  public struct Configuration: Hashable {
    public let isSelected: Bool
    public let tintColors: [TKRadioButtonState: UIColor]
    public let size: CGFloat
    public let handler: RadioButtonHandlerClosure?
    
    public init(
      isSelected: Bool,
      size: CGFloat,
      tintColors: [TKRadioButtonState: UIColor] = [
        .selected: .Button.primaryBackground,
        .deselected: .Button.tertiaryBackground
      ],
      handler: RadioButtonHandlerClosure?
    ) {
      self.isSelected = isSelected
      self.tintColors = tintColors
      self.size = size
      self.handler = handler
    }
    
    public static func == (
      lhs: TKUIListItemRadioButtonAccessoryView.Configuration,
      rhs: TKUIListItemRadioButtonAccessoryView.Configuration
    ) -> Bool {
      lhs.isSelected == rhs.isSelected
    }
    
    public func hash(into hasher: inout Hasher) {
      hasher.combine(isSelected)
    }
  }
  
  public func configure(configuration: Configuration) {
    radioButton.isSelected = configuration.isSelected
    radioButton.tintColors = configuration.tintColors
    radioButton.size = configuration.size
    radioButton.didToggle = configuration.handler
    
    setNeedsLayout()
  }
  
  public override func sizeThatFits(_ size: CGSize) -> CGSize {
    return radioButton.sizeThatFits(size)
  }
  
  public override func layoutSubviews() {
    super.layoutSubviews()
    radioButton.frame = bounds
  }
}

// MARK: - Private methods

private extension TKUIListItemRadioButtonAccessoryView {
  func setup() {
    addSubview(radioButton)
    radioButton.isUserInteractionEnabled = false
  }
}

