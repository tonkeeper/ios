import SnapKit
import TKUIKit
import UIKit

final class StakingDetailsLinksView: TKView, ConfigurableView {
    let titleView = TKListTitleView()
    let stackView = UIStackView()
    private var titleHeightConstraint: Constraint?

    var titleHeight: CGFloat = 56 {
        didSet { titleHeightConstraint?.update(offset: titleHeight) }
    }

    struct Model {
        struct LinkItem {
            let title: String
            let icon: UIImage
            let action: () -> Void
        }

        let header: TKListTitleView.Model
        let linkItems: [LinkItem]
    }

    func configure(model: Model) {
        titleView.configure(model: model.header)

        stackView.arrangedSubviews.forEach { $0.removeFromSuperview() }
        let chunks = model.linkItems.chunked(into: 2)
        for chunk in chunks {
            let stackView = UIStackView()
            stackView.axis = .horizontal
            stackView.spacing = 8
            for item in chunk {
                var configuration = TKButton.Configuration.actionButtonConfiguration(category: .secondary, size: .small)
                configuration.content = TKButton.Configuration.Content(title: .plainString(item.title), icon: item.icon)
                configuration.iconPosition = .left
                configuration.action = item.action
                configuration.spacing = 8
                let button = TKButton(configuration: configuration)
                stackView.addArrangedSubview(button)
            }
            self.stackView.addArrangedSubview(stackView)
        }
    }

    override func setup() {
        super.setup()

        stackView.alignment = .leading
        stackView.axis = .vertical
        stackView.spacing = 8

        addSubview(titleView)
        addSubview(stackView)

        setupConstraints()
    }

    func setupConstraints() {
        titleView.snp.makeConstraints { make in
            make.top.left.right.equalTo(self)
            titleHeightConstraint = make.height.equalTo(titleHeight).constraint
        }

        stackView.snp.makeConstraints { make in
            make.top.equalTo(titleView.snp.bottom)
            make.left.right.equalTo(self)
            make.bottom.equalTo(self)
        }
    }
}

extension Array {
    func chunked(into size: Int) -> [[Element]] {
        return stride(from: 0, to: count, by: size).map {
            Array(self[$0 ..< Swift.min($0 + size, count)])
        }
    }
}
