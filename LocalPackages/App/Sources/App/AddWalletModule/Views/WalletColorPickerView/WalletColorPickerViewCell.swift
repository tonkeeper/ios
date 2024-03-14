import UIKit
import TKUIKit

final class WalletColorPickerViewCell: UICollectionViewCell, ConfigurableView {
  
  private let colorView = ColorView()
  
  override init(frame: CGRect) {
    super.init(frame: frame)
    setup()
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  override func layoutSubviews() {
    super.layoutSubviews()
    
    colorView.frame = CGRect(
      x: 0,
      y: .colorViewTopInset,
      width: .colorViewSide,
      height: .colorViewSide
    )
  }
  
  override func prepareForReuse() {
    super.prepareForReuse()
    colorView.isSelected = false
  }
  
  override func updateConfiguration(using state: UICellConfigurationState) {
    super.updateConfiguration(using: state)
    UIView.animate(withDuration: 0.2, delay: 0, options: .curveEaseInOut) {
      self.colorView.isSelected = state.isSelected
    }
  }

  func configure(model: WalletColorPickerView.Model.ColorItem) {
    colorView.color = model.color
  }
}

private extension WalletColorPickerViewCell {
  func setup() {
    addSubview(colorView)
  }
}

private extension WalletColorPickerViewCell {
  final class ColorView: UIView {
    var isSelected = false {
      didSet {
        updateFillViewFrame()
      }
    }
    
    var color: UIColor = .clear {
      didSet {
        borderView.layer.borderColor = color.cgColor
        fillView.backgroundColor = color
      }
    }
    
    private let borderView = UIView()
    private let fillView = UIView()
    
    init() {
      super.init(frame: .zero)
      setup()
    }
    
    required init?(coder: NSCoder) {
      fatalError("init(coder:) has not been implemented")
    }
    
    override func layoutSubviews() {
      super.layoutSubviews()
      
      borderView.frame = bounds
      borderView.layer.cornerRadius = borderView.bounds.height/2
      updateFillViewFrame()
    }
    
    private func setup() {
      borderView.layer.borderWidth = .borderWidth
      borderView.backgroundColor = .Background.page
      
      addSubview(borderView)
      addSubview(fillView)
    }
    
    private func updateFillViewFrame() {
      fillView.frame = isSelected ? bounds.insetBy(dx: 8, dy: 8) : bounds
      fillView.layer.cornerRadius = fillView.bounds.height/2
    }
  }
}

private extension CGFloat {
  static let borderWidth: CGFloat = 3
  static let colorViewSide: CGFloat = 36
  static let colorViewTopInset: CGFloat = 20
}
