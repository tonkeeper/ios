import UIKit
import TKUIKit

final class LedgerContentView: TKView, ConfigurableView {
  let bluetoothView = LedgerBluetoothView()
  let contentView = UIStackView()
  
  override func setup() {
    super.setup()
    
    backgroundColor = .Background.content
    layer.cornerRadius = .cornerRadius
    layer.masksToBounds = true
    
    contentView.axis = .vertical
    contentView.spacing = .stepsSpacing
    
    addSubview(bluetoothView)
    addSubview(contentView)
    
    setupConstraints()
  }
  
  override func setupConstraints() {
    bluetoothView.snp.makeConstraints { make in
      make.top.left.right.equalTo(self)
    }
    
    contentView.snp.makeConstraints { make in
      make.top.equalTo(bluetoothView.snp.bottom).offset(UIEdgeInsets.contentPadding.top)
      make.left.equalTo(self).inset(UIEdgeInsets.contentPadding.left)
      make.right.equalTo(self).inset(UIEdgeInsets.contentPadding.right)
        .priority(.required.advanced(by: -1))
      make.bottom.equalTo(self).offset(-UIEdgeInsets.contentPadding.bottom)
        .priority(.required.advanced(by: -1))
    }
  }
  
  final class Model {
    var bluetoothViewModel: LedgerBluetoothView.Model
    var stepModels: [LedgerStepView.Model]
    
    init(bluetoothViewModel: LedgerBluetoothView.Model, 
         stepModels: [LedgerStepView.Model]) {
      self.bluetoothViewModel = bluetoothViewModel
      self.stepModels = stepModels
    }
  }
  
  func configure(model: Model) {
    bluetoothView.configure(model: model.bluetoothViewModel)
    contentView.arrangedSubviews.forEach {
      $0.removeFromSuperview()
    }
    for stepModel in model.stepModels {
      let stepView = LedgerStepView()
      stepView.configure(model: stepModel)
      contentView.addArrangedSubview(stepView)
    }
  }
}

private extension CGFloat {
  static let cornerRadius: CGFloat = 16
  static let stepsSpacing: CGFloat = 8
}

private extension UIEdgeInsets {
  static let contentPadding = UIEdgeInsets(top: 20, left: 16, bottom: 20, right: 16)
}
