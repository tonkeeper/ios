import TKUIKit
import UIKit

final class AllUpdatesStoryCell: UICollectionViewCell, ReusableView, ConfigurableView {
    private let containerView: UIView = {
        let view = UIView()
        view.backgroundColor = .Background.content
        view.layer.cornerRadius = 16
        view.layer.masksToBounds = true
        return view
    }()

    private let previewImageView: TKImageView = {
        let imageView = TKImageView()
        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
        return imageView
    }()

    private let textContainer: UIView = {
        let view = UIView()
        view.backgroundColor = .Background.content
        return view
    }()

    private let titleLabel = UILabel()
    private let descriptionLabel = UILabel()

    private let chevronImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.image = .TKUIKit.Icons.Size16.chevronRight
        imageView.tintColor = .Icon.tertiary
        return imageView
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    struct Configuration: Hashable {
        let id: String
        let previewURL: URL
        let title: String
        let description: String

        func hash(into hasher: inout Hasher) {
            hasher.combine(id)
        }

        static func == (lhs: Configuration, rhs: Configuration) -> Bool {
            lhs.id == rhs.id
        }
    }

    func configure(model: Configuration) {
        titleLabel.attributedText = model.title.withTextStyle(
            .label1,
            color: .Text.primary,
            alignment: .left,
            lineBreakMode: .byTruncatingTail
        )

        descriptionLabel.attributedText = model.description.withTextStyle(
            .body2,
            color: .Text.secondary,
            alignment: .left,
            lineBreakMode: .byTruncatingTail
        )
        descriptionLabel.numberOfLines = 1

        previewImageView.configure(model: TKImageView.Model(
            image: .urlImage(model.previewURL),
            size: .size(CGSize(width: contentView.bounds.width - 32, height: 238)),
            corners: .none
        ))
    }

    private func setup() {
        contentView.backgroundColor = .Background.page

        contentView.addSubview(containerView)
        containerView.addSubview(previewImageView)
        containerView.addSubview(textContainer)
        textContainer.addSubview(titleLabel)
        textContainer.addSubview(descriptionLabel)
        textContainer.addSubview(chevronImageView)

        setupConstraints()
    }

    private func setupConstraints() {
        containerView.snp.makeConstraints { make in
            make.edges.equalTo(contentView).inset(UIEdgeInsets(top: 0, left: 16, bottom: 8, right: 16))
        }

        previewImageView.snp.makeConstraints { make in
            make.top.left.right.equalTo(containerView)
            make.height.equalTo(238)
        }

        textContainer.snp.makeConstraints { make in
            make.top.equalTo(previewImageView.snp.bottom)
            make.left.right.bottom.equalTo(containerView)
        }

        titleLabel.snp.makeConstraints { make in
            make.top.equalTo(textContainer).offset(16)
            make.left.equalTo(textContainer).offset(16)
            make.right.equalTo(chevronImageView.snp.left).offset(-8)
        }

        descriptionLabel.snp.makeConstraints { make in
            make.top.equalTo(titleLabel.snp.bottom).offset(2)
            make.left.equalTo(textContainer).offset(16)
            make.right.equalTo(chevronImageView.snp.left).offset(-8)
            make.bottom.equalTo(textContainer).offset(-16)
        }

        chevronImageView.snp.makeConstraints { make in
            make.right.equalTo(textContainer).offset(-16)
            make.centerY.equalTo(textContainer)
            make.size.equalTo(CGSize(width: 16, height: 16))
        }
    }
}
