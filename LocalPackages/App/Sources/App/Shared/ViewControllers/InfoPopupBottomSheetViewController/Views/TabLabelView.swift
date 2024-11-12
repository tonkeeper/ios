import UIKit
import TKUIKit

extension InfoPopupBottomSheetViewController {

  final class TabLabelView: UIView, ConfigurableView {

    private let paddingContainer: TKPaddingContainerView = {
      let container = TKPaddingContainerView()
      container.padding = UIEdgeInsets(top: 16, left: 16, bottom: 16, right: 16)
      container.backgroundColor = .Background.content
      container.layer.masksToBounds = true
      container.layer.cornerRadius = 12
      return container
    }()

    private let stackView: UIStackView = {
      let view = UIStackView()
      view.axis = .vertical
      view.spacing = 16
      return view
    }()

    override init(frame: CGRect) {
      super.init(frame: frame)

      setup()
    }
    
    required init?(coder: NSCoder) {
      fatalError("init(coder:) has not been implemented")
    }
    
    private func setup() {
      paddingContainer.addSubview(stackView)
      addSubview(paddingContainer)

      paddingContainer.snp.makeConstraints { $0.edges.equalToSuperview() }
    }

    // MARK: -  ConfigurableView

    struct Model {
      let content: [String]
    }

    func configure(model: Model) {
      stackView.arrangedSubviews.forEach { $0.removeFromSuperview() }

      model.content.forEach {
        let label = composeLabel()
        let text = $0.withTabTextStyle(.body2, color: .Text.primary)
        label.attributedText = text
        stackView.addArrangedSubview(label)
      }

      paddingContainer.setViews([stackView])
    }

    private func composeLabel() -> UILabel {
      let label = UILabel()
      label.numberOfLines = 0
      return label
    }
  }
}
