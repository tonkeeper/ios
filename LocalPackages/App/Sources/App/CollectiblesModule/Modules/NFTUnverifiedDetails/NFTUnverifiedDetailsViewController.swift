import UIKit
import TKUIKit

final class NFTUnverifiedDetailsViewController: UIViewController {

  var didUpdateHeight: (() -> Void)?

  var headerItem: TKUIKit.TKPullCardHeaderItem?

  var didUpdatePullCardHeaderItem: ((TKUIKit.TKPullCardHeaderItem) -> Void)?

  let scrollView = UIScrollView()

  private let stackView: UIStackView = {
    let stackView = UIStackView()
    stackView.axis = .vertical
    stackView.alignment = .center
    return stackView
  }()

  private lazy var titleLabel: UILabel = {
    let label = UILabel()
    label.numberOfLines = 0
    return label
  }()

  private lazy var captionLabel: UILabel = {
    let label = UILabel()
    label.numberOfLines = 0
    return label
  }()

  private lazy var labelsStackView: UIStackView = {
    let stackView = UIStackView(arrangedSubviews: [titleLabel, captionLabel])
    stackView.axis = .vertical
    stackView.spacing = 4
    return stackView
  }()

  private let buttonsPaddingContainer: TKPaddingContainerView = {
    let container = TKPaddingContainerView()
    container.padding = UIEdgeInsets(top: 16, left: 16, bottom: 16, right: 16)
    return container
  }()

  override func viewDidLoad() {
    super.viewDidLoad()

    setup()
  }

  private func setup() {
    scrollView.addSubview(stackView)

    view.addSubview(scrollView)

    stackView.addArrangedSubview(labelsStackView)
  }
}

// MARK: -  TKBottomSheetScrollContentViewController

extension NFTUnverifiedDetailsViewController: TKBottomSheetScrollContentViewController {

  func calculateHeight(withWidth width: CGFloat) -> CGFloat {
    stackView.systemLayoutSizeFitting(
      CGSize(width: width, height: 0),
      withHorizontalFittingPriority: .required,
      verticalFittingPriority: .fittingSizeLevel
    ).height
  }
}
