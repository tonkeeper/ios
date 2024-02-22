import UIKit
import TKUIKit

final class CollectibleDetailsView: UIView, ConfigurableView {
  
  private let scrollView: UIScrollView = {
    return TKUIScrollView()
  }()
  private let scrollContent = UIView()
  private let contentStackView: UIStackView = {
    let stackView = UIStackView()
    stackView.axis = .vertical
    return stackView
  }()
  
  let collectibleView = CollectibleDetailsCollectibleView()
  let collectionDescriptionView = CollectibleDetailsCollectionDescriptionView()
  let buttonsView = CollectibleDetailsButtonsView()
  let propertiesCarouselView = CollectibleDetailsPropertiesСarouselView()
  let detailsView = CollectibleDetailsDetailsView()

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
    let collectibleDescriptionModel: CollectibleDetailsCollectibleView.Model?
    let collectionDescriptionModel: CollectibleDetailsCollectionDescriptionView.Model?
    let buttonsModel: CollectibleDetailsButtonsView.Model?
    let propertiesModel: CollectibleDetailsPropertiesСarouselView.Model?
    let detailsModel: CollectibleDetailsDetailsView.Model?
  }
  
  func configure(model: Model) {
    if let collectibleDescriptionModel = model.collectibleDescriptionModel {
      collectibleView.isHidden = false
      collectibleView.configure(model: collectibleDescriptionModel)
    } else {
      collectibleView.isHidden = true
    }
    
    if let collectionDescriptionModel = model.collectionDescriptionModel {
      collectionDescriptionView.isHidden = false
      collectionDescriptionView.configure(model: collectionDescriptionModel)
    } else {
      collectionDescriptionView.isHidden = true
    }
    
    if let buttonsModel = model.buttonsModel {
      buttonsView.isHidden = false
      buttonsView.configure(model: buttonsModel)
    } else {
      buttonsView.isHidden = true
    }
    
    if let propertiesModel = model.propertiesModel {
      propertiesCarouselView.isHidden = false
      propertiesCarouselView.configure(model: propertiesModel)
    } else {
      propertiesCarouselView.isHidden = true
    }
    
    if let detailsModel = model.detailsModel {
      detailsView.isHidden = false
      detailsView.configure(model: detailsModel)
    } else {
      detailsView.isHidden = true
    }
  }
}

// MARK: - Private

private extension CollectibleDetailsView {
  func setup() {
    backgroundColor = .Background.page
    
    scrollView.contentInset.bottom = 16
    
    addSubview(scrollView)
    scrollView.addSubview(scrollContent)
    scrollContent.addSubview(contentStackView)
    
    contentStackView.addArrangedSubview(collectibleView)
    contentStackView.addArrangedSubview(collectionDescriptionView)
    contentStackView.addArrangedSubview(buttonsView)
    contentStackView.addArrangedSubview(propertiesCarouselView)
    contentStackView.addArrangedSubview(detailsView)
    
    contentStackView.setCustomSpacing(16, after: collectibleView)
    
    setupConstraints()
  }
  
  func setupConstraints() {
    scrollView.translatesAutoresizingMaskIntoConstraints = false
    contentStackView.translatesAutoresizingMaskIntoConstraints = false
    scrollContent.translatesAutoresizingMaskIntoConstraints = false
    
    NSLayoutConstraint.activate([
      scrollView.topAnchor.constraint(equalTo: topAnchor),
      scrollView.leftAnchor.constraint(equalTo: leftAnchor),
      scrollView.rightAnchor.constraint(equalTo: rightAnchor),
      scrollView.bottomAnchor.constraint(equalTo: bottomAnchor),
      
      scrollContent.topAnchor.constraint(equalTo: scrollView.topAnchor),
      scrollContent.leftAnchor.constraint(equalTo: scrollView.leftAnchor),
      scrollContent.rightAnchor.constraint(equalTo: scrollView.rightAnchor),
      scrollContent.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
      scrollContent.widthAnchor.constraint(equalTo: scrollView.widthAnchor),
      
      contentStackView.topAnchor.constraint(equalTo: scrollContent.topAnchor),
      contentStackView.leftAnchor.constraint(equalTo: scrollContent.leftAnchor, constant: 16),
      contentStackView.rightAnchor.constraint(equalTo: scrollContent.rightAnchor, constant: -16),
      contentStackView.bottomAnchor.constraint(equalTo: scrollContent.bottomAnchor)
    ])
  }
}
