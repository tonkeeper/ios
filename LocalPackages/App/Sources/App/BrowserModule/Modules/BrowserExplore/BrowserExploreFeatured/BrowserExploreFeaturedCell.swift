import TKUIKit
import UIKit

final class BrowserExploreFeaturedCell: UICollectionViewCell, ReusableView, ConfigurableView {
    let posterImageView = TKImageView()
    let listView = TKListItemContentView()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        listView.frame = CGRect(
            x: .padding,
            y: bounds.height - .listItemHeight - .padding,
            width: bounds.width - .padding * 2,
            height: .listItemHeight
        )
    }

    struct Model {
        let posterImageModel: TKImageView.Model
        let listConfiguration: TKListItemContentView.Configuration
        let tapClosure: (() -> Void)?
    }

    func configure(model: Model) {
        posterImageView.configure(model: model.posterImageModel)
        listView.configuration = model.listConfiguration
        setNeedsLayout()
    }

    override func prepareForReuse() {
        super.prepareForReuse()
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
            make.edges.equalTo(contentView)
        }
    }
}

private extension CGFloat {
    static let padding: CGFloat = 16
    static let listItemHeight: CGFloat = 52
}
