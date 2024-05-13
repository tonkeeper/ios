import UIKit
import TKUIKit

final class ReceiveView: UIView, ConfigurableView {
  
  let scrollView = TKUIScrollView()
  
  let contentStackView: UIStackView = {
    let stackView = UIStackView()
    stackView.axis = .vertical
    return stackView
  }()
  
  let titleDescriptionView: TKTitleDescriptionView = {
    let view = TKTitleDescriptionView(size: .medium)
    view.padding = .titleDescriptionPadding
    return view
  }()
  
  let qrCodeView = ReceiveQRCodeView()
  let qrCodeContainer: TKPaddingContainerView = {
    let container = TKPaddingContainerView()
    container.padding = .qrCodePadding
    return container
  }()
  
  let buttonsView = ReceiveButtonsView()
  
  override init(frame: CGRect) {
    super.init(frame: frame)
    setup()
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  struct Model {
    public enum Image {
      case image(UIImage)
      case asyncImage(ImageDownloadTask)
    }
    public let titleDescriptionModel: TKTitleDescriptionView.Model
    public let buttonsModel: ReceiveButtonsView.Model
    public let address: String?
    public let addressButtonAction: () -> Void
    public let image: Image
    public let tag: TKUITagView.Configuration?
  }
  
  func configure(model: Model) {
    titleDescriptionView.configure(model: model.titleDescriptionModel)
    buttonsView.configure(model: model.buttonsModel)
    switch model.image {
    case .image(let image):
      qrCodeView.tokenImageView.image = image
    case .asyncImage(let imageDownloadTask):
      imageDownloadTask.start(
        imageView: qrCodeView.tokenImageView,
        size: CGSize(width: 44, height: 44),
        cornerRadius: 32
      )
    }

    qrCodeView.setTagModel(model.tag)
    qrCodeView.addressButton.address = model.address
    qrCodeView.addressButton.tapHandler = {
      model.addressButtonAction()
    }
    qrCodeView.sizeToFit()
    setNeedsLayout()
  }
}

private extension ReceiveView {
  func setup() {
    backgroundColor = .Background.page
    
    scrollView.delaysContentTouches = false
    
    titleDescriptionView.setContentHuggingPriority(.required, for: .vertical)
    scrollView.contentInset.bottom = 32
    
    addSubview(scrollView)
    scrollView.addSubview(contentStackView)
    contentStackView.addArrangedSubview(titleDescriptionView)
    contentStackView.addArrangedSubview(qrCodeContainer)
    contentStackView.setCustomSpacing(16, after: qrCodeContainer)
    contentStackView.addArrangedSubview(buttonsView)
    
    qrCodeContainer.setViews([qrCodeView])
    
    setupConstraints()
  }
  
  func setupConstraints() {
    contentStackView.translatesAutoresizingMaskIntoConstraints = false
    scrollView.translatesAutoresizingMaskIntoConstraints = false
    
    NSLayoutConstraint.activate([
      scrollView.topAnchor.constraint(equalTo: topAnchor),
      scrollView.leftAnchor.constraint(equalTo: leftAnchor),
      scrollView.rightAnchor.constraint(equalTo: rightAnchor),
      scrollView.bottomAnchor.constraint(equalTo: bottomAnchor),
      scrollView.widthAnchor.constraint(equalTo: widthAnchor),
      
      contentStackView.topAnchor.constraint(equalTo: scrollView.topAnchor),
      contentStackView.leftAnchor.constraint(equalTo: scrollView.leftAnchor),
      contentStackView.rightAnchor.constraint(equalTo: scrollView.rightAnchor),
      contentStackView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
      contentStackView.widthAnchor.constraint(equalTo: scrollView.widthAnchor),
    ])
  }
}

private extension NSDirectionalEdgeInsets {
  static let titleDescriptionPadding = NSDirectionalEdgeInsets(
    top: 24,
    leading: 32,
    bottom: 16,
    trailing: 32
  )
}

private extension UIEdgeInsets {
  static let qrCodePadding = UIEdgeInsets(
    top: 16,
    left: 47,
    bottom: 0,
    right: 47
  )
}
