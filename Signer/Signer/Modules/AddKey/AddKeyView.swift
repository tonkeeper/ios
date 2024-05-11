import UIKit
import TKUIKit

final class AddKeyView: UIView {
  let titleDescriptionView = TKTitleDescriptionView(size: .big)
  let buttonsContainer: UIStackView = {
    let stackView = UIStackView()
    stackView.axis = .vertical
    stackView.spacing = .buttonsContainerSpacing
    return stackView
  }()
  let createButton = TKButton()
  let importButton = TKButton()
  
  // MARK: - Init
  
  override init(frame: CGRect) {
    super.init(frame: frame)
    setup()
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
}

private extension AddKeyView {
  func setup() {
    titleDescriptionView.padding.leading = 32
    titleDescriptionView.padding.trailing = 32
    titleDescriptionView.padding.bottom = 32
    
    addSubview(titleDescriptionView)
    addSubview(buttonsContainer)
    
    buttonsContainer.addArrangedSubview(createButton)
    buttonsContainer.addArrangedSubview(importButton)
    
    setupConstraints()
  }
  
  func setupConstraints() {
    titleDescriptionView.translatesAutoresizingMaskIntoConstraints = false
    buttonsContainer.translatesAutoresizingMaskIntoConstraints = false
    createButton.translatesAutoresizingMaskIntoConstraints = false
    importButton.translatesAutoresizingMaskIntoConstraints = false
    
    NSLayoutConstraint.activate([
      titleDescriptionView.topAnchor.constraint(equalTo: topAnchor),
      titleDescriptionView.leftAnchor.constraint(equalTo: leftAnchor),
      titleDescriptionView.rightAnchor.constraint(equalTo: rightAnchor),
      
      importButton.heightAnchor.constraint(equalToConstant: 56),
      createButton.heightAnchor.constraint(equalToConstant: 56),
      
      buttonsContainer.topAnchor.constraint(
        equalTo: titleDescriptionView.bottomAnchor, 
        constant: NSDirectionalEdgeInsets.buttonsContainerPadding.top
      ),
      buttonsContainer.leadingAnchor.constraint(
        equalTo: leadingAnchor,
        constant: NSDirectionalEdgeInsets.buttonsContainerPadding.leading
      ),
      buttonsContainer.bottomAnchor.constraint(
        equalTo: bottomAnchor,
        constant: -NSDirectionalEdgeInsets.buttonsContainerPadding.bottom
      ).withPriority(.defaultHigh),
      buttonsContainer.trailingAnchor.constraint(
        equalTo: trailingAnchor,
        constant: -NSDirectionalEdgeInsets.buttonsContainerPadding.trailing
      ).withPriority(.defaultHigh),
    ])
  }
}

private extension CGFloat {
  static let titleBottomPadding: CGFloat = 32
  static let buttonsContainerSpacing: CGFloat = 16
}

private extension NSDirectionalEdgeInsets {
  static let buttonsContainerPadding = NSDirectionalEdgeInsets(top: 16, leading: 32, bottom: 32, trailing: 32)
}
