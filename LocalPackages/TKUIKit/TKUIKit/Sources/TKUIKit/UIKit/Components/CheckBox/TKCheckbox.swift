import UIKit

public class TKCheckBox: UIView {

  public var isChecked: Bool = true {
    didSet {
      setNeedsDisplay()
    }
  }

  // Initialization methods
  override init(frame: CGRect) {
    super.init(frame: frame)
    commonInit()
  }

  required init?(coder: NSCoder) {
    super.init(coder: coder)
    commonInit()
  }

  private func commonInit() {
    backgroundColor = .clear
    setNeedsDisplay()
  }

  @objc private func toggleChecked() {
    isChecked.toggle()
  }

  public override func draw(_ rect: CGRect) {
    // Drawing code
    let outerCircleRect = CGRect(x: 3, y: 3, width: rect.width - 6, height: rect.height - 6)
    let innerCircleRect = CGRect(x: rect.width * 0.3, y: rect.height * 0.3, width: rect.width * 0.4, height: rect.height * 0.4)
    
    if let context = UIGraphicsGetCurrentContext() {
      // Draw outer circle
      context.setStrokeColor(isChecked ? UIColor.systemBlue.cgColor : UIColor.Text.secondary.cgColor)
      context.setLineWidth(2)
      context.strokeEllipse(in: outerCircleRect)
      
      // Draw inner circle if checked
      if isChecked {
        context.setFillColor(UIColor.systemBlue.cgColor)
        context.fillEllipse(in: innerCircleRect)
      }
    }
  }
}
