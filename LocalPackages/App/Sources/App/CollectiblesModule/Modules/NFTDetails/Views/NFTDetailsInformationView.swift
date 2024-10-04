import UIKit
import TKUIKit

final class NFTDetailsInformationView: UIView, ConfigurableView {
  
  struct Model {
    struct Image {
      let imageViewModel: TKImageView.Model
      let isBlurVisible: Bool
    }
    let image: Image
    let itemInformationViewModel: NFTDetailsItemInformationView.Model
    let collectionInformationViewModel: NFTDetailsCollectionInformationView.Model?
  }
  
  func configure(model: Model) {
    imageView.configure(model: model.image.imageViewModel)
    imageBlurView.isHidden = !model.image.isBlurVisible
    itemInformationView.configure(model: model.itemInformationViewModel)
    if let collectionInformationViewModel = model.collectionInformationViewModel {
      separatorView.isHidden = false
      collectionInformationView.isHidden = false
      collectionInformationView.configure(model: collectionInformationViewModel)
    } else {
      separatorView.isHidden = true
      collectionInformationView.isHidden = true
    }
  }
  
  private let containerView = UIView()
  private let imageView = TKImageView()
  private let imageBlurView = TKSecureBlurView()
  private let itemInformationView = NFTDetailsItemInformationView()
  private let separatorView = TKSeparatorView()
  private let collectionInformationView = NFTDetailsCollectionInformationView()
  
  private let stackView: UIStackView = {
    let stackView = UIStackView()
    stackView.axis = .vertical
    return stackView
  }()
  
  override init(frame: CGRect) {
    super.init(frame: frame)
    setup()
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  private func setup() {
    containerView.backgroundColor = .Background.content
    containerView.layer.masksToBounds = true
    containerView.layer.cornerRadius = 16
    containerView.layer.cornerCurve = .continuous
    
    imageBlurView.isHidden = true
    
    addSubview(containerView)
    containerView.addSubview(stackView)
    stackView.addArrangedSubview(imageView)
    stackView.addArrangedSubview(itemInformationView)
    stackView.addArrangedSubview(separatorView)
    stackView.addArrangedSubview(collectionInformationView)
    imageView.addSubviews(imageBlurView)
    
    setupConstraints()
  }
  
  private func setupConstraints() {
    containerView.snp.makeConstraints { make in
      make.top.equalTo(self)
      make.left.right.equalTo(self).inset(16)
      make.bottom.equalTo(self).offset(-16)
    }
    
    stackView.snp.makeConstraints { make in
      make.edges.equalTo(containerView)
    }
    
    imageView.snp.makeConstraints { make in
      make.height.equalTo(imageView.snp.width)
    }
    
    imageBlurView.snp.makeConstraints { make in
      make.edges.equalTo(imageView)
    }
  }
}
