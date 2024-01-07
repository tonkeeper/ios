import UIKit
import TKUIKit

final class OnboardingRootView: UIView, ConfigurableView {
  let titleDescriptionView: TKTitleDescriptionView = {
    let view = TKTitleDescriptionView(size: .big)
    view.padding.bottom = .titleBottomPadding
    view.padding.leading = 32
    view.padding.trailing = 32
    return view
  }()
  
  let buttonsContainer: TKPaddingContainerView = {
    let view = TKPaddingContainerView()
    view.padding = TKPaddingContainerView.buttonsContainerPadding
    view.spacing = TKPaddingContainerView.buttonsContainerSpacing
    return view
  }()
  
  let createButton = TKUIActionButton(category: .primary, size: .large)
  let importButton = TKUIActionButton(category: .secondary, size: .large)
  let coverImageView: UIImageView = {
    let imageView = UIImageView()
    imageView.image = .Onboarding.cover
    imageView.contentMode = .scaleAspectFill
    return imageView
  }()
  
  override init(frame: CGRect) {
    super.init(frame: frame)
    setup()
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  struct Model {
    let titleDescriptionModel: TKTitleDescriptionView.Model
    let createButtonModel: TKUIActionButton.Model
    let importButtonModel: TKUIActionButton.Model
  }
  
  func configure(model: Model) {
    titleDescriptionView.configure(model: model.titleDescriptionModel)
    createButton.configure(model: model.createButtonModel)
    importButton.configure(model: model.importButtonModel)
  }
  
}

private extension OnboardingRootView {
  func setup() {
    backgroundColor = .Background.page
    
    buttonsContainer.setViews([createButton, importButton])
    
    addSubview(coverImageView)
    addSubview(titleDescriptionView)
    addSubview(buttonsContainer)
    
    setupConstraints()
  }
  
  func setupConstraints() {
    titleDescriptionView.translatesAutoresizingMaskIntoConstraints = false
    buttonsContainer.translatesAutoresizingMaskIntoConstraints = false
    coverImageView.translatesAutoresizingMaskIntoConstraints = false
    
    coverImageView.setContentCompressionResistancePriority(.defaultLow, for: .vertical)
    
    NSLayoutConstraint.activate([
      buttonsContainer.bottomAnchor.constraint(equalTo: bottomAnchor),
      buttonsContainer.leftAnchor.constraint(equalTo: leftAnchor),
      buttonsContainer.rightAnchor.constraint(equalTo: rightAnchor),
      
      titleDescriptionView.bottomAnchor.constraint(equalTo: buttonsContainer.topAnchor),
      titleDescriptionView.leftAnchor.constraint(equalTo: leftAnchor),
      titleDescriptionView.rightAnchor.constraint(equalTo: rightAnchor),
      
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
