import UIKit
import TKUIKit
import SnapKit

final class ChartHeaderView: UIView, TKConfigurableView {
  
  private let contentContainer = UIView()
  private let priceLabel = UILabel()
  private let diffLabel = UILabel()
  private let priceDiffLabel = UILabel()
  private let dateLabel = UILabel()
  
  override init(frame: CGRect) {
    super.init(frame: frame)
    setup()
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  override var intrinsicContentSize: CGSize {
    CGSize(width: UIView.noIntrinsicMetric, height: .height)
  }
  
  struct Configuration: Hashable {
    struct Diff: Hashable {
      enum Direction: Hashable {
        case up
        case down
        case none
      }
      
      let diff: String
      let priceDiff: String
      let direction: Direction
    }
    
    let price: NSAttributedString
    let diff: NSAttributedString
    let priceDiff: NSAttributedString
    let date: NSAttributedString
    
    init(price: String,
         diff: Diff,
         date: String) {
      self.price = price.withTextStyle(
        .priceTextStyle,
        color: .Text.primary,
        alignment: .left,
        lineBreakMode: .byTruncatingTail
      )
      self.date = date.withTextStyle(
        .otherTextStyle,
        color: .Text.secondary,
        alignment: .left,
        lineBreakMode: .byTruncatingTail
      )
      
      let diffColor: UIColor
      switch diff.direction {
      case .up:
        diffColor = .Accent.green
      case .down:
        diffColor = .Accent.red
      case .none:
        diffColor = .Text.secondary
      }
      
      self.diff = diff.diff.withTextStyle(
        .otherTextStyle,
        color: diffColor,
        alignment: .left,
        lineBreakMode: .byTruncatingTail
      )
      
      self.priceDiff = diff.priceDiff.withTextStyle(
        .otherTextStyle,
        color: diffColor.withAlphaComponent(0.44),
        alignment: .left,
        lineBreakMode: .byTruncatingTail
      )
    }
  }
  
  func configure(configuration: Configuration) {
    priceLabel.attributedText = configuration.price
    diffLabel.attributedText = configuration.diff
    priceDiffLabel.attributedText = configuration.priceDiff
    dateLabel.attributedText = configuration.date
  }
  
  private func setup() {
    addSubview(contentContainer)
    contentContainer.addSubview(priceLabel)
    contentContainer.addSubview(diffLabel)
    contentContainer.addSubview(priceDiffLabel)
    contentContainer.addSubview(dateLabel)
    
    setupConstraints()
  }
  
  private func setupConstraints() {
    
    diffLabel.setContentHuggingPriority(.required, for: .horizontal)
    
    contentContainer.snp.makeConstraints { make in
      make.edges.equalTo(self).inset(UIEdgeInsets.containerPadding)
    }
    
    priceLabel.snp.makeConstraints { make in
      make.top.left.right.equalTo(contentContainer)
    }
    
    diffLabel.snp.makeConstraints { make in
      make.top.equalTo(priceLabel.snp.bottom)
      make.left.equalTo(contentContainer)
    }
    
    priceDiffLabel.snp.makeConstraints { make in
      make.top.equalTo(diffLabel)
      make.left.equalTo(diffLabel.snp.right).offset(CGFloat.diffSpacing)
      make.right.equalTo(contentContainer)
    }
    
    dateLabel.snp.makeConstraints { make in
      make.top.equalTo(diffLabel.snp.bottom)
      make.left.equalTo(contentContainer)
      make.right.equalTo(contentContainer)
      make.bottom.equalTo(contentContainer)
    }
  }
}

private extension CGFloat {
  static let height: CGFloat = 92
  static let diffSpacing: CGFloat = 8
}

private extension UIEdgeInsets {
  static var containerPadding = UIEdgeInsets(top: 24, left: 28, bottom: 0, right: 28)
}

private extension TKTextStyle {
  static var priceTextStyle: TKTextStyle {
    TKTextStyle(
      font: .monospacedSystemFont(ofSize: 20, weight: .bold),
      lineHeight: 28
    )
  }
  
  static var otherTextStyle: TKTextStyle {
    TKTextStyle(
      font: .monospacedSystemFont(ofSize: 14, weight: .medium),
      lineHeight: 20
    )
  }
}
