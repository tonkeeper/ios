import UIKit
import TKUIKit

final class OnboardingView: UIView {
  let titleDescriptionView: TKTitleDescriptionHeaderView = {
    let view = TKTitleDescriptionHeaderView(size: .big)
    view.padding.bottom = .titleBottomPadding
    return view
  }()
  let buttonsContainer: UIStackView = {
    let stackView = UIStackView()
    stackView.axis = .vertical
    stackView.isLayoutMarginsRelativeArrangement = true
    stackView.directionalLayoutMargins = .buttonsContainerPadding
    stackView.spacing = .buttonsContainerSpacing
    return stackView
  }()
  let createButton = TKButton.titleButton(buttonCategory: .primary, buttonSize: .large)
  let importButton = TKButton.titleButton(buttonCategory: .secondary, buttonSize: .large)
  let coverImageView: UIImageView = {
    let imageView = UIImageView()
    imageView.image = .Images.tonsignCover
    imageView.contentMode = .scaleAspectFill
    return imageView
  }()
  
  // MARK: - Init
  
  override init(frame: CGRect) {
    super.init(frame: frame)
    setup()
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
}

private extension OnboardingView {
  func setup() {
    backgroundColor = .Background.page
  
    addSubview(coverImageView)
    addSubview(titleDescriptionView)
    addSubview(buttonsContainer)
    buttonsContainer.addArrangedSubview(createButton)
    buttonsContainer.addArrangedSubview(importButton)
    
    setupConstraints()
  }
  
  func setupConstraints() {
    titleDescriptionView.translatesAutoresizingMaskIntoConstraints = false
    buttonsContainer.translatesAutoresizingMaskIntoConstraints = false
    coverImageView.translatesAutoresizingMaskIntoConstraints = false
    
    coverImageView.setContentCompressionResistancePriority(.defaultLow, for: .vertical)
    
    NSLayoutConstraint.activate([
      buttonsContainer.bottomAnchor.constraint(equalTo: safeAreaLayoutGuide.bottomAnchor),
      buttonsContainer.rightAnchor.constraint(equalTo: rightAnchor),
      buttonsContainer.leftAnchor.constraint(equalTo: leftAnchor),
      
      titleDescriptionView.bottomAnchor.constraint(equalTo: buttonsContainer.topAnchor),
      titleDescriptionView.leftAnchor.constraint(equalTo: buttonsContainer.leftAnchor),
      titleDescriptionView.rightAnchor.constraint(equalTo: buttonsContainer.rightAnchor),
      
      coverImageView.bottomAnchor.constraint(equalTo: titleDescriptionView.topAnchor, constant: -24),
      coverImageView.leftAnchor.constraint(equalTo: titleDescriptionView.leftAnchor),
      coverImageView.rightAnchor.constraint(equalTo: titleDescriptionView.rightAnchor),
      coverImageView.topAnchor.constraint(equalTo: topAnchor)
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
