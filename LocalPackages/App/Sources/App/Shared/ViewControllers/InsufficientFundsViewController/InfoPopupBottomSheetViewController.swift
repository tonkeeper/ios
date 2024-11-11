import UIKit
import TKUIKit

final class InfoPopupBottomSheetViewController: UIViewController, TKBottomSheetScrollContentViewController {
  
  struct Configuration {

    enum BodyView {
      case textWithTabs(content: [String])
    }

    let image: UIImage?
    let imageTintColor: UIColor?
    let title: String
    let caption: String
    let bodyContent: [BodyView]?
    let buttons: [TKButton.Configuration]
  }
  
  var didUpdateHeight: (() -> Void)?
  
  var headerItem: TKPullCardHeaderItem?
  var didUpdatePullCardHeaderItem: ((TKPullCardHeaderItem) -> Void)?
  func calculateHeight(withWidth width: CGFloat) -> CGFloat {
    stackView.systemLayoutSizeFitting(
      CGSize(width: width, height: 0),
      withHorizontalFittingPriority: .required,
      verticalFittingPriority: .fittingSizeLevel
    ).height
  }
  
  let scrollView = UIScrollView()
  
  private let imageView = UIImageView()
  private let titleLabel = UILabel()
  private let captionLabel = UILabel()
  private let titleCaptionStackView: UIStackView = {
    let stackView = UIStackView()
    stackView.axis = .vertical
    stackView.spacing = 4
    return stackView
  }()
  private let titleCaptionPaddingView = UIView()
  
  private let stackView: UIStackView = {
    let stackView = UIStackView()
    stackView.axis = .vertical
    stackView.alignment = .center
    return stackView
  }()
  private let buttonsPaddingContainer: TKPaddingContainerView = {
    let container = TKPaddingContainerView()
    container.padding = UIEdgeInsets(top: 16, left: 16, bottom: 16, right: 16)
    return container
  }()
  
  var configuration: Configuration? {
    didSet {
      updateConfiguration()
    }
  }
  
  override func viewDidLoad() {
    super.viewDidLoad()
    
    setup()
  }
  
  private func setup() {
    titleLabel.numberOfLines = 0
    captionLabel.numberOfLines = 0

    view.addSubview(scrollView)
    scrollView.addSubview(stackView)
    
    titleCaptionPaddingView.addSubview(titleCaptionStackView)
    
    scrollView.snp.makeConstraints { make in
      make.edges.equalTo(self.view)
    }
    stackView.snp.makeConstraints { make in
      make.edges.width.equalTo(scrollView)
    }
    titleCaptionStackView.snp.makeConstraints { make in
      make.top.equalTo(titleCaptionPaddingView)
      make.left.right.equalTo(titleCaptionPaddingView).inset(32)
      make.bottom.equalTo(titleCaptionPaddingView).inset(16)
    }
    buttonsPaddingContainer.snp.makeConstraints { make in
      make.width.equalTo(stackView)
    }
  }

  private func updateConfiguration() {
    stackView.arrangedSubviews.forEach { $0.removeFromSuperview() }
    stackView.addArrangedSubview(imageView)
    stackView.setCustomSpacing(12, after: imageView)
    stackView.addArrangedSubview(titleCaptionPaddingView)

    titleCaptionStackView.arrangedSubviews.forEach { $0.removeFromSuperview() }
    titleCaptionStackView.addArrangedSubview(titleLabel)
    titleCaptionStackView.addArrangedSubview(captionLabel)

    imageView.isHidden = configuration?.image == nil
    imageView.image = configuration?.image
    imageView.tintColor = configuration?.imageTintColor

    titleLabel.attributedText = configuration?.title.withTextStyle(.h2, color: .Text.primary, alignment: .center)
    captionLabel.attributedText = configuration?.caption.withTextStyle(.body1, color: .Text.secondary, alignment: .center)

    updateBodyConfiguration()

    stackView.addArrangedSubview(buttonsPaddingContainer)
    let buttons = (configuration?.buttons ?? []).map { configuration in
      let button = TKButton()
      button.configuration = configuration
      return button
    }
    buttonsPaddingContainer.setViews(buttons)
  }

  private func updateBodyConfiguration() {
    guard let bodyContent = configuration?.bodyContent, !bodyContent.isEmpty else {
      return
    }

    bodyContent.forEach { item in
      let containerView = TKPaddingContainerView()
      containerView.padding = UIEdgeInsets(top: 16, left: 16, bottom: 16, right: 16)
      stackView.addArrangedSubview(containerView)

      containerView.snp.makeConstraints { $0.width.equalTo(stackView) }

      switch item {
      case .textWithTabs(let content):
        let tabView = TabLabelView()
        tabView.configure(model: .init(content: content))
        containerView.setViews([tabView])

        tabView.snp.makeConstraints { $0.edges.equalToSuperview() }
      }
    }
  }
}
