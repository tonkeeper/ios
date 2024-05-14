import UIKit
import TKUIKit
import SnapKit

final class SwapInputTokenView: UIControl {

  var didTap: (() -> Void)?

  var token: SwapInputTokenView.Token? = nil {
    didSet {
      label.text = token?.name ?? "Choose"

      if let image = token?.image {
        imageDownloadTask?.cancel()
        updateContraints(imageHidden: false)
        switch image {
        case .image(let uIImage):
          imageView.image = uIImage
        case .asyncImage(let imageDownloadTask):
          self.imageDownloadTask = imageDownloadTask
          imageDownloadTask.start(imageView: imageView, size: CGSize(width: 28, height: 28), cornerRadius: 14)
        }
      } else {
        updateContraints(imageHidden: true)
      }
    }
  }

  struct Token {
    let name: String
    let image: SendV3View.Model.Amount.Token.Image? // TODO: - refactor it
  }
  
  override var isHighlighted: Bool {
    didSet {
      backgroundView.backgroundColor = isHighlighted ? .Button.tertiaryBackgroundHighlighted : .Button.tertiaryBackground
      shrink(down: isHighlighted)
    }
  }

  private let imageView = UIImageView()
  private let label = UILabel()
  
  private let stackView: UIStackView = {
    let stackView = UIStackView()
    stackView.isLayoutMarginsRelativeArrangement = true
    stackView.directionalLayoutMargins = NSDirectionalEdgeInsets(
      top: 0,
      leading: 4,
      bottom: 0,
      trailing: 12
    )
    stackView.alignment = .center
    stackView.spacing = 6
    return stackView
  }()
  
  private let backgroundView: UIView = {
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
    backgroundView.layer.cornerRadius = 18
  }

  private func setup() {
    addSubview(backgroundView)
    addSubview(stackView)
    
    setContentCompressionResistancePriority(.required, for: .horizontal)
    stackView.setContentCompressionResistancePriority(.required, for: .horizontal)
    label.setContentCompressionResistancePriority(.required, for: .horizontal)
    imageView.setContentCompressionResistancePriority(.required, for: .horizontal)
    
    layer.masksToBounds = true
    
    imageView.contentMode = .scaleAspectFit
    
    backgroundView.isUserInteractionEnabled = false
    
    label.textColor = .Button.tertiaryForeground
    label.font = TKTextStyle.label1.font
    label.isUserInteractionEnabled = false

    stackView.isUserInteractionEnabled = false

    stackView.addArrangedSubview(imageView)
    stackView.addArrangedSubview(label)

    setupConstraints()

    addAction(UIAction(handler: { [weak self] _ in
      self?.bounce()
      self?.didTap?()
    }), for: .touchUpInside)
  }

  func setupConstraints() {
    backgroundView.snp.makeConstraints { make in
      make.edges.equalTo(stackView)
    }
    
    stackView.snp.makeConstraints { make in
      make.edges.equalTo(self)
    }
    
    imageView.snp.makeConstraints { make in
      make.width.height.equalTo(0)
    }
  }

  func updateContraints(imageHidden: Bool) {
    if imageHidden {
      imageView.image = nil
      imageView.snp.remakeConstraints { make in
        make.width.height.equalTo(0)
      }
      stackView.directionalLayoutMargins = NSDirectionalEdgeInsets(
        top: 0,
        leading: 8,
        bottom: 0,
        trailing: 14
      )
    } else {
      imageView.snp.remakeConstraints { make in
        make.width.height.equalTo(24)
      }
      stackView.directionalLayoutMargins = NSDirectionalEdgeInsets(
        top: 0,
        leading: 4,
        bottom: 0,
        trailing: 12
      )
    }
  }

  override var intrinsicContentSize: CGSize {
    CGSize(width: UIView.noIntrinsicMetric, height: 36)
  }
}
