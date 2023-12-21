import UIKit

final class TitleConnectionView: UIView, ConfigurableView {
  
  let titleLabel = UILabel()
  let connectionStatusView = ConnectionStatusView()
  
  private var titleLabelBottomConstraint: NSLayoutConstraint?
  private var titleLabelCenterYConstraint: NSLayoutConstraint?
  
  override init(frame: CGRect) {
    super.init(frame: frame)
    setup()
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  // MARK: - ConfigurableView
  
  struct Model {
    let title: String
    let statusViewModel: ConnectionStatusView.Model?
  }
  
  func configure(model: Model) {
    titleLabel.attributedText = model.title.attributed(
      with: .h3,
      alignment: .center,
      color: .Text.primary
    )
    let connectionStatusViewAlpha: CGFloat
    if let statusViewModel = model.statusViewModel {
      connectionStatusView.configure(model: statusViewModel)
      self.layoutIfNeeded()
      connectionStatusViewAlpha = 1.0
      titleLabelCenterYConstraint?.isActive = false
      titleLabelBottomConstraint?.isActive = true
      
    } else {
      connectionStatusViewAlpha = 0
      titleLabelBottomConstraint?.isActive = false
      titleLabelCenterYConstraint?.isActive = true
    }
    UIView.animate(withDuration: 0.2, delay: 0, options: .curveEaseInOut) {
      self.connectionStatusView.alpha = connectionStatusViewAlpha
      self.layoutIfNeeded()
    }
  }
}

private extension TitleConnectionView {
  func setup() {
    addSubview(titleLabel)
    addSubview(connectionStatusView)
    
    connectionStatusView.alpha = 0
    setupConstraints()
  }
  
  func setupConstraints() {
    titleLabel.translatesAutoresizingMaskIntoConstraints = false
    connectionStatusView.translatesAutoresizingMaskIntoConstraints = false
    
    titleLabelCenterYConstraint = titleLabel.centerYAnchor.constraint(
      equalTo: centerYAnchor
    )
    titleLabelBottomConstraint = titleLabel.bottomAnchor.constraint(
      equalTo: centerYAnchor
    )
    titleLabelCenterYConstraint?.isActive = true
    
    NSLayoutConstraint.activate([
      titleLabel.centerXAnchor.constraint(equalTo: centerXAnchor),
      
      connectionStatusView.topAnchor.constraint(equalTo: centerYAnchor),
      connectionStatusView.centerXAnchor.constraint(equalTo: centerXAnchor)
    ])
  }
}
