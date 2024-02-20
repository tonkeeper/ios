import UIKit
import TKUIKit

public final class PasscodeView: UIView, ConfigurableView {
  let keyboardView = TKKeyboardView(configuration: .passcodeConfiguration(biometry: nil))
  let topContainer = UIView()
  
  override init(frame: CGRect) {
    super.init(frame: frame)
    setup()
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  public struct Model {
    let keyboardConfiguration: TKKeyboardView.Configuration
  }
  
  public func configure(model: Model) {
    keyboardView.configuration = model.keyboardConfiguration
  }
}

private extension PasscodeView {
  func setup() {
    backgroundColor = .Background.page
    
    addSubview(keyboardView)
    addSubview(topContainer)
    
    setupConstraints()
  }
  
  func setupConstraints() {
    keyboardView.translatesAutoresizingMaskIntoConstraints = false
    topContainer.translatesAutoresizingMaskIntoConstraints = false

    NSLayoutConstraint.activate([
      keyboardView.bottomAnchor.constraint(equalTo: safeAreaLayoutGuide.bottomAnchor),
      keyboardView.leftAnchor.constraint(equalTo: leftAnchor),
      keyboardView.rightAnchor.constraint(equalTo: rightAnchor),
      
      topContainer.topAnchor.constraint(equalTo: safeAreaLayoutGuide.topAnchor),
      topContainer.leftAnchor.constraint(equalTo: leftAnchor),
      topContainer.bottomAnchor.constraint(equalTo: keyboardView.topAnchor),
      topContainer.rightAnchor.constraint(equalTo: rightAnchor)
    ])
  }
}
