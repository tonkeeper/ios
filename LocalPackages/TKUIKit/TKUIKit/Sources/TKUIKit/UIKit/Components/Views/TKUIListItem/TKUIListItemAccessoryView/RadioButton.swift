import UIKit

public enum TKRadioButtonState {
  case selected
  case deselected
}

public final class RadioButton: UIControl {
  private let outerLayer = CAShapeLayer()
  private let innerLayer = CAShapeLayer()
  
  public var didToggle: ((_ isSelected: Bool) -> Void)?
  
  public var tintColors: [TKRadioButtonState: UIColor] = [:] {
    didSet {
      updateAppearance()
    }
  }
  
  public var padding: UIEdgeInsets = .zero {
    didSet {
      invalidateIntrinsicContentSize()
      setNeedsLayout()
    }
  }
  
  public var size: CGFloat = .zero {
    didSet {
      updateAppearance()
      invalidateIntrinsicContentSize()
      setNeedsLayout()
    }
  }
  
  public override var isSelected: Bool {
    didSet {
      guard isSelected != oldValue else { return }
      updateAppearance()
      sendActions(for: .valueChanged)
    }
  }
  
  public override var isEnabled: Bool {
    didSet {
      guard isSelected != oldValue else { return }
      alpha = isEnabled ? 1 : 0.48
    }
  }
  
  public override init(frame: CGRect) {
    super.init(frame: frame)
    setup()
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  public override func layoutSubviews() {
    super.layoutSubviews()
    updateAppearance()
  }
  
  public override func sizeThatFits(_ size: CGSize) -> CGSize {
    .init(width: self.size + padding.left + padding.right,
          height: self.size + padding.top + padding.bottom)
  }
  
  public override var intrinsicContentSize: CGSize {
    CGSize(width: self.size, height: self.size)
  }
}

// MARK: - Private methods

private extension RadioButton {
  func setup() {
    updateAppearance()
    setNeedsLayout()
  }
  
  func updateAppearance() {
    let diameter = size * 0.8
    let lineWidth: CGFloat = diameter * 0.1
    let innerDiameter = diameter * 0.5
    
    let outerPath = UIBezierPath(
      ovalIn: CGRect(
        x: (bounds.width - diameter - padding.right + padding.left) / 2,
        y: (bounds.height - diameter - padding.bottom + padding.top) / 2,
        width: diameter,
        height: diameter
      )
    )
    
    let innerPath = UIBezierPath(
      ovalIn: CGRect(
        x: (bounds.width - innerDiameter - padding.right + padding.left) / 2,
        y: (bounds.height - innerDiameter - padding.bottom + padding.top) / 2,
        width: innerDiameter,
        height: innerDiameter
      )
    )
    
    let outerColor = tintColors[isSelected ? .selected : .deselected]
    outerLayer.path = outerPath.cgPath
    outerLayer.lineWidth = lineWidth
    outerLayer.fillColor = UIColor.clear.cgColor
    outerLayer.strokeColor = outerColor?.cgColor
    
    let innerColor = isSelected ? tintColors[.selected] : .clear
    innerLayer.path = innerPath.cgPath
    innerLayer.fillColor = innerColor?.cgColor
    
    if outerLayer.superlayer == nil {
      layer.addSublayer(outerLayer)
    }
    
    if innerLayer.superlayer == nil {
      layer.addSublayer(innerLayer)
    }
  }
}
