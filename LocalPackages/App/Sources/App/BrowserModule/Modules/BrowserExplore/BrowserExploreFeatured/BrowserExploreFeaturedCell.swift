import TKUIKit
import UIKit

final class BrowserExploreFeaturedCell: UICollectionViewCell, ReusableView, ConfigurableView {
  
  let posterImageView = UIImageView()
  let listView = TKUIListItemView()
  
  private var imageDownloadTask: ImageDownloadTask?
  
  override init(frame: CGRect) {
    super.init(frame: frame)
    setup()
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  override func layoutSubviews() {
    super.layoutSubviews()
    imageDownloadTask?.cancel()
    imageDownloadTask?.start(
      imageView: posterImageView,
      size: bounds.size,
      cornerRadius: nil
    )
    
    listView.frame = CGRect(
      x: .padding,
      y: bounds.height - .listItemHeight - .padding,
      width: bounds.width,
      height: .listItemHeight
    )
  }
  
  struct Model {
    let posterImageTask: ImageDownloadTask
    let listModel: TKUIListItemView.Configuration
  }
  
  func configure(model: Model) {
    imageDownloadTask = model.posterImageTask
    listView.configure(configuration: model.listModel)
    setNeedsLayout()
  }
  
  override func prepareForReuse() {
    super.prepareForReuse()
    imageDownloadTask?.cancel()
    imageDownloadTask = nil
    posterImageView.image = nil
  }
}

private extension BrowserExploreFeaturedCell {
  func setup() {
    layer.cornerRadius = 16
    layer.masksToBounds = true
    backgroundColor = .Background.content
    
    posterImageView.contentMode = .scaleAspectFill
    
    contentView.addSubview(posterImageView)
    contentView.addSubview(listView)
    
    setupConstraints()
  }
  
  func setupConstraints() {
    posterImageView.snp.makeConstraints { make in
      make.edges.equalTo(self)
    }
  }
}

private extension CGFloat {
  static let padding: CGFloat = 16
  static let listItemHeight: CGFloat = 52
}
