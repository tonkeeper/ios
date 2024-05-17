import UIKit
import TKUIKit
import SnapKit

class UnderlinedSegmentedControl: UISegmentedControl {
  
  private lazy var underlineView: UIView = {
    let view = UIView()
    view.translatesAutoresizingMaskIntoConstraints = false
    return view
  }()
  
  private var underlineLeadingConstraint: Constraint?
  
  var font: UIFont = TKTextStyle.label1.font {
    didSet {
      updateTextAttributes()
    }
  }
  
  var selectedTextColor: UIColor = .Text.primary {
    didSet {
      updateTextAttributes()
    }
  }
  
  var unselectedTextColor: UIColor = .Text.secondary {
    didSet {
      updateTextAttributes()
    }
  }
  
  var underlineColor: UIColor = .Accent.blue {
    didSet {
      underlineView.backgroundColor = underlineColor
    }
  }
  
  override var selectedSegmentTintColor: UIColor? {
    didSet {
      if let selectedSegmentTintColor {
        selectedTextColor = selectedSegmentTintColor
      }
    }
  }
  
  override init(items: [Any]?) {
    super.init(items: items)
    setup()
  }
  
  required init?(coder: NSCoder) {
    super.init(coder: coder)
    setup()
  }
  
  private func setup() {
    backgroundColor = .clear
    tintColor = .clear
    
    setBackgroundImage(imageWithColor(color: .clear), for: .normal, barMetrics: .default)
    setBackgroundImage(imageWithColor(color: .clear), for: .selected, barMetrics: .default)
    setDividerImage(imageWithColor(color: .clear), forLeftSegmentState: .normal, rightSegmentState: .normal, barMetrics: .default)
    
    updateTextAttributes()
    setupUnderline()
    
    addTarget(self, action: #selector(segmentValueChanged), for: .valueChanged)
    
    clipsToBounds = false
  }
  
  private func updateTextAttributes() {
    let normalTextAttributes: [NSAttributedString.Key: Any] = [
      .foregroundColor: unselectedTextColor,
      .font: font
    ]
    let selectedTextAttributes: [NSAttributedString.Key: Any] = [
      .foregroundColor: selectedTextColor,
      .font: font
    ]
    
    setTitleTextAttributes(normalTextAttributes, for: .normal)
    setTitleTextAttributes(selectedTextAttributes, for: .selected)
  }
  
  private func setupUnderline() {
    addSubview(underlineView)
    underlineView.backgroundColor = underlineColor
    underlineView.layer.cornerRadius = CGFloat.underlineHeight
    
    let underlineHeight: CGFloat = CGFloat.underlineHeight
    underlineView.snp.makeConstraints { make in
      make.height.equalTo(underlineHeight)
      make.top.equalTo(self.snp.bottom)
      make.width.equalTo(self).multipliedBy(1.0 / CGFloat(numberOfSegments))
      self.underlineLeadingConstraint = make.leading.equalTo(self).constraint
    }
    
    updateUnderlinePosition(animated: false)
  }
  
  @objc private func segmentValueChanged() {
    updateUnderlinePosition(animated: true)
  }
  
  private func updateUnderlinePosition(animated: Bool) {
    guard numberOfSegments > 0 else { return }
    
    let segmentWidth = bounds.width / CGFloat(numberOfSegments)
    let underlineXPosition = selectedSegmentIndex == UISegmentedControl.noSegment ? 0 : segmentWidth * CGFloat(selectedSegmentIndex)
    
    underlineLeadingConstraint?.update(offset: underlineXPosition)
    
    if animated {
      UIView.animate(withDuration: CGFloat.animationDuration, delay: 0, options: .curveEaseInOut) {
        self.layoutIfNeeded()
      }
    }
  }
  
  private func imageWithColor(color: UIColor) -> UIImage {
    let rect = CGRect(x: 0, y: 0, width: 1, height: 1)
    UIGraphicsBeginImageContextWithOptions(rect.size, false, 0.0)
    color.setFill()
    UIRectFill(rect)
    let image = UIGraphicsGetImageFromCurrentImageContext()
    UIGraphicsEndImageContext()
    return image ?? UIImage()
  }
}

private extension CGFloat {
  static let animationDuration: CGFloat = 0.3
  static let underlineHeight: CGFloat = 3.0
}
