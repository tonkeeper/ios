import UIKit
import TKUIKit
import SnapKit

extension SendPickerCell {
  final class RightView: UIView, ConfigurableView {
    
    var didTapAmount: (() -> Void)?
    
    private let containerView = UIView()
    
    override init(frame: CGRect) {
      super.init(frame: frame)
      setup()
    }
    
    required init?(coder: NSCoder) {
      fatalError("init(coder:) has not been implemented")
    }
    
    enum Model {
      case none
      case amount(SendPickerCell.AmountView.Model)
      case empty(SendPickerCell.EmptyAccessoriesView.Model)
    }

    func configure(model: Model) {
      containerView.subviews.forEach { $0.removeFromSuperview() }
      switch model {
      case .none:
        break
      case .amount(let model):
        let amountView = SendPickerCell.AmountView()
        amountView.didTap = { [weak self] in
          self?.didTapAmount?()
        }
        amountView.configure(model: model)
        containerView.addSubview(amountView)
        amountView.snp.makeConstraints { make in
          make.bottom.left.right.equalTo(containerView)
        }
      case .empty(let model):
        let view = SendPickerCell.EmptyAccessoriesView()
        view.configure(model: model)
        containerView.addSubview(view)
        view.snp.makeConstraints { make in
          make.edges.equalTo(containerView)
        }
      }
    }
  }
}

private extension SendPickerCell.RightView {
  func setup() {
    addSubview(containerView)
    
    setupConstraints()
  }
  
  func setupConstraints() {
    setContentHuggingPriority(.required, for: .horizontal)
    containerView.setContentHuggingPriority(.required, for: .horizontal)
    
    containerView.snp.makeConstraints { make in
      make.top.equalTo(self).offset(13)
      make.bottom.equalTo(self).offset(-14)
      make.right.equalTo(self).offset(-16)
      make.left.equalTo(self)
    }
  }
}
