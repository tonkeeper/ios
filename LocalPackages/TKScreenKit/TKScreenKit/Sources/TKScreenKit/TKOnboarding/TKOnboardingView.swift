import UIKit
import TKUIKit

public final class TKOnboardingView: UIView, ConfigurableView {
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

  let primaryButton = TKButton()
  let secondaryButton = TKButton()
  let coverImageView: UIImageView = {
    let imageView = UIImageView()
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
  
  public struct Model {
    let coverImage: UIImage?
    let titleDescriptionModel: TKTitleDescriptionView.Model
    let primaryButtonConfiguration: TKButton.Configuration
    let secondaryButtonConfiguration: TKButton.Configuration
  }
  
  public func configure(model: Model) {
    coverImageView.image = model.coverImage
    titleDescriptionView.configure(model: model.titleDescriptionModel)
    primaryButton.configuration = model.primaryButtonConfiguration
    secondaryButton.configuration = model.secondaryButtonConfiguration
  }
}

private extension TKOnboardingView {
  func setup() {
    backgroundColor = .Background.page
    
    buttonsContainer.setViews([primaryButton, secondaryButton])
    
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
      coverImageView.topAnchor.constraint(equalTo: topAnchor),
      
      primaryButton.heightAnchor.constraint(equalToConstant: 56),
      secondaryButton.heightAnchor.constraint(equalToConstant: 56),
    ])
  }
}

private extension CGFloat {
  static let titleBottomPadding: CGFloat = 32
  static let buttonsContainerSpacing: CGFloat = 16
}
