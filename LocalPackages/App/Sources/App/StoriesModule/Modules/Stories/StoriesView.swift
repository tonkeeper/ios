import UIKit
import TKUIKit
import KeeperCore

final class StoriesView: UIView, ConfigurableView {
  
  var imageBackgroundView = UIImageView()
  let titleWithSubtitleView = StoriesTitleWithSubtitleView()
  let storiesButtonView = StoriesButtonView()

  let contentStackView: UIStackView = {
    let stackView = UIStackView()
    stackView.axis = .vertical
    stackView.alignment = .fill
    stackView.spacing = 28
    return stackView
  }()
  
  override init(frame: CGRect) {
    super.init(frame: frame)
    setup()
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  struct Model {
    public let currentPageIndex: Int
    public let pages: [StoriesController.StoryPage]
  }
  
  func configure(model: Model) {
    let currentPage = model.pages[model.currentPageIndex]
    titleWithSubtitleView.configure(model: .init(title: currentPage.title, subtitle: currentPage.description))
    
    if ((currentPage.button) != nil) {
      storiesButtonView.showButton()
      storiesButtonView.configure(model: .init(action: currentPage.button!.action, title: currentPage.button!.title))
    } else {
      storiesButtonView.hideButton()
    }
    
    imageBackgroundView.image = currentPage.backgroundImage

    setNeedsLayout()
  }
}

private extension StoriesView {
  func setup() {
    imageBackgroundView.contentMode = .scaleAspectFill
    imageBackgroundView.layer.cornerRadius = 20
    imageBackgroundView.layer.masksToBounds = true

    contentStackView.addArrangedSubview(titleWithSubtitleView)
    contentStackView.addArrangedSubview(storiesButtonView)
    imageBackgroundView.addSubview(contentStackView)
    addSubview(imageBackgroundView)
    
    setupConstraints()
  }
  
  func setupConstraints() {
    imageBackgroundView.translatesAutoresizingMaskIntoConstraints = false
    contentStackView.translatesAutoresizingMaskIntoConstraints = false

    NSLayoutConstraint.activate([
      imageBackgroundView.topAnchor.constraint(equalTo: topAnchor),
      imageBackgroundView.leftAnchor.constraint(equalTo: leftAnchor),
      imageBackgroundView.rightAnchor.constraint(equalTo: rightAnchor),
      imageBackgroundView.bottomAnchor.constraint(equalTo: safeAreaLayoutGuide.bottomAnchor),

      contentStackView.topAnchor.constraint(equalTo: imageBackgroundView.topAnchor),
      contentStackView.leftAnchor.constraint(equalTo: imageBackgroundView.leftAnchor),
      contentStackView.rightAnchor.constraint(equalTo: imageBackgroundView.rightAnchor),
      contentStackView.bottomAnchor.constraint(equalTo: imageBackgroundView.bottomAnchor, constant: .bottomSpacing),
    ])
  }
}

private extension CGFloat {
  static let bottomSpacing: CGFloat = -28
}
