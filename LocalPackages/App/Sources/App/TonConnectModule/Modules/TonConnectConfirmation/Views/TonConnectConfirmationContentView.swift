import UIKit
import TKUIKit
import TKCore

final class TonConnectConfirmationContentView: UIView, ConfigurableView {
    
  private let actionsView = HistoryCellContentView()
  private let feeView = TonConnectConfirmationFeeView()
  
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
    let actionsConfiguration: HistoryCellContentView.Model
    let feeModel: TonConnectConfirmationFeeView.Model
  }
  
  func configure(model: Model) {
    actionsView.configure(model: model.actionsConfiguration)
    feeView.configure(model: model.feeModel)
  }
}

private extension TonConnectConfirmationContentView {

  func setup() {
    actionsView.isUserInteractionEnabled = false
    
    addSubview(actionsView)
    addSubview(feeView)
    setupConstraints()
  }
  
  func setupConstraints() {
    actionsView.translatesAutoresizingMaskIntoConstraints = false
    feeView.translatesAutoresizingMaskIntoConstraints = false
    
    NSLayoutConstraint.activate([
      actionsView.topAnchor.constraint(equalTo: topAnchor),
      actionsView.leftAnchor.constraint(equalTo: leftAnchor),
      actionsView.rightAnchor.constraint(equalTo: rightAnchor),
      
      feeView.topAnchor.constraint(equalTo: actionsView.bottomAnchor),
      feeView.leftAnchor.constraint(equalTo: leftAnchor),
      feeView.bottomAnchor.constraint(equalTo: bottomAnchor),
      feeView.rightAnchor.constraint(equalTo: rightAnchor)
    ])
  }
}

extension UIView {
  
  func findViewController() -> UIViewController? {
    if let nextResponder = self.next as? UIViewController {
      return nextResponder
    } else if let nextResponder = self.next as? UIView {
      return nextResponder.findViewController()
    } else {
      return nil
    }
  }
}
