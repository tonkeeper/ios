import UIKit
import TKUIKit
import SnapKit

final class SendV3AmountInputTokenView: UIControl {
  
  override var isHighlighted: Bool {
    didSet {
      backgroundView.backgroundColor = isHighlighted ? .Button.tertiaryBackgroundHighlighted : .Button.tertiaryBackground
    }
  }
  
  var image: SendV3View.Model.Amount.Token.Image? {
    didSet {
      imageDownloadTask?.cancel()
      switch image {
      case .image(let uIImage):
        imageView.image = uIImage
      case .asyncImage(let imageDownloadTask):
        self.imageDownloadTask = imageDownloadTask
        imageDownloadTask.start(imageView: imageView, size: CGSize(width: 24, height: 24), cornerRadius: 12)
      case nil:
        imageView.image = nil
      }
    }
  }
  
  let imageView = UIImageView()
  let label = UILabel()
  let switchImageView = UIImageView()
  
  let stackView: UIStackView = {
    let stackView = UIStackView()
    stackView.isLayoutMarginsRelativeArrangement = true
    stackView.directionalLayoutMargins = NSDirectionalEdgeInsets(
      top: 8,
      leading: 8,
      bottom: 8,
      trailing: 12
    )
    stackView.alignment = .center
    stackView.spacing = 6
    return stackView
  }()
  
  let backgroundView: UIView = {
    let view = UIView()
    view.backgroundColor = .Button.tertiaryBackground
    return view
  }()
  
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
    backgroundView.layer.cornerRadius = 20
  }

  private func setup() {
    addSubview(backgroundView)
    addSubview(stackView)
    
    setContentCompressionResistancePriority(.required, for: .horizontal)
    stackView.setContentCompressionResistancePriority(.required, for: .horizontal)
    switchImageView.setContentCompressionResistancePriority(.required, for: .horizontal)
    label.setContentCompressionResistancePriority(.required, for: .horizontal)
    imageView.setContentCompressionResistancePriority(.required, for: .horizontal)
    
    layer.masksToBounds = true
    
    imageView.contentMode = .scaleAspectFit
    
    backgroundView.isUserInteractionEnabled = false
    
    label.textColor = .Button.tertiaryForeground
    label.font = TKTextStyle.label2.font
    label.isUserInteractionEnabled = false
    
    switchImageView.image = .TKUIKit.Icons.Size16.switch
    switchImageView.tintColor = .Icon.secondary
    switchImageView.isUserInteractionEnabled = false
    
    stackView.isUserInteractionEnabled = false
    
    stackView.addArrangedSubview(imageView)
    stackView.addArrangedSubview(label)
    stackView.addArrangedSubview(switchImageView)
    
    backgroundView.snp.makeConstraints { make in
      make.edges.equalTo(stackView)
    }
    
    stackView.snp.makeConstraints { make in
      make.top.right.bottom.equalTo(self).inset(12)
      make.left.equalTo(self)
    }
    
    imageView.snp.makeConstraints { make in
      make.width.height.equalTo(24)
    }
  }
}
