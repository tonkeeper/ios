import TKUIKit
import UIKit

public final class AccountEventCellActionView: UIControl, ConfigurableView, ReusableView {
    var isSeparatorVisible: Bool = true {
        didSet {
            updateSeparatorVisibility()
        }
    }

    let highlightView = TKHighlightView()
    let contentContainer = TKPassthroughView()
    let contentView = TKListItemContentView()
    let commentView = CommentView()
    let encryptedCommentView = EncyptedCommentView()
    let descriptionView = CommentView()
    let nftView = NFTView()
    let separatorView = TKSeparatorView()

    override public var isHighlighted: Bool {
        didSet {
            highlightView.isHighlighted = isHighlighted
            updateSeparatorVisibility()
        }
    }

    override public init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    @available(*, unavailable)
    public required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    public struct Model {
        let contentConfiguration: TKListItemContentView.Configuration
        let commentConfiguration: CommentView.Configuration?
        let encryptedCommentConfiguration: EncyptedCommentView.Model?
        let descriptionConfiguration: CommentView.Configuration?
        let nftConfiguration: NFTView.Configuration?
        let isInProgress: Bool

        public init(
            contentConfiguration: TKListItemContentView.Configuration,
            commentConfiguration: CommentView.Configuration? = nil,
            encryptedCommentConfiguration: EncyptedCommentView.Model? = nil,
            descriptionConfiguration: CommentView.Configuration? = nil,
            nftConfiguration: NFTView.Configuration? = nil,
            isInProgress: Bool = false
        ) {
            self.contentConfiguration = contentConfiguration
            self.commentConfiguration = commentConfiguration
            self.encryptedCommentConfiguration = encryptedCommentConfiguration
            self.descriptionConfiguration = descriptionConfiguration
            self.nftConfiguration = nftConfiguration
            self.isInProgress = isInProgress
        }
    }

    public func configure(model: Model) {
        contentView.configuration = model.contentConfiguration
        if let commentConfiguration = model.commentConfiguration {
            commentView.isHidden = false
            commentView.configure(configuration: commentConfiguration)
        } else {
            commentView.isHidden = true
        }

        if let encryptedCommentConfiguration = model.encryptedCommentConfiguration {
            encryptedCommentView.isHidden = false
            encryptedCommentView.configure(model: encryptedCommentConfiguration)
        } else {
            encryptedCommentView.isHidden = true
        }

        if let descriptionConfiguration = model.descriptionConfiguration {
            descriptionView.isHidden = false
            descriptionView.configure(configuration: descriptionConfiguration)
        } else {
            descriptionView.isHidden = true
        }

        if let nftConfiguration = model.nftConfiguration {
            nftView.isHidden = false
            nftView.configure(configuration: nftConfiguration)
        } else {
            nftView.isHidden = true
        }

        setNeedsLayout()
    }

    override public func sizeThatFits(_ size: CGSize) -> CGSize {
        let contentSize = size.inset(by: .contentPadding)
        let contentSizeThatFits = contentView.sizeThatFits(CGSize(width: contentSize.width, height: 0))
        let itemsWidth = contentSize.width - 60

        let commentSize: CGSize
        if commentView.isHidden {
            commentSize = .zero
        } else {
            commentSize = commentView.sizeThatFits(CGSize(width: itemsWidth, height: 0))
        }

        let encryptedCommentSize: CGSize
        if encryptedCommentView.isHidden {
            encryptedCommentSize = .zero
        } else {
            encryptedCommentSize = encryptedCommentView.sizeThatFits(CGSize(width: itemsWidth, height: 0))
        }

        let descriptionSize: CGSize
        if descriptionView.isHidden {
            descriptionSize = .zero
        } else {
            descriptionSize = descriptionView.sizeThatFits(CGSize(width: itemsWidth, height: 0))
        }

        let nftSize: CGSize
        if nftView.isHidden {
            nftSize = .zero
        } else {
            nftSize = nftView.sizeThatFits(CGSize(width: itemsWidth, height: 0))
        }

        let height = contentSizeThatFits.height
            + commentSize.height
            + encryptedCommentSize.height
            + descriptionSize.height
            + nftSize.height
            + UIEdgeInsets.contentPadding.top
            + UIEdgeInsets.contentPadding.bottom

        return CGSize(width: size.width, height: height)
    }

    override public func layoutSubviews() {
        super.layoutSubviews()
        highlightView.frame = bounds

        let contentFrame = bounds.inset(by: .contentPadding)
        contentContainer.frame = contentFrame

        let contentSizeThatFits = contentView.sizeThatFits(CGSize(width: contentFrame.width, height: 0))
        contentView.frame = CGRect(x: 0, y: 0, width: contentFrame.width, height: contentSizeThatFits.height)

        let itemsPadding: CGFloat = 60
        let itemsWidth = contentFrame.width - itemsPadding

        if !nftView.isHidden {
            nftView.frame = CGRect(
                origin: CGPoint(x: itemsPadding, y: contentView.frame.maxY),
                size: nftView.sizeThatFits(CGSize(width: itemsWidth, height: 0))
            )
        } else {
            nftView.frame = CGRect(
                origin: CGPoint(x: itemsPadding, y: contentView.frame.maxY),
                size: .zero
            )
        }

        if !commentView.isHidden {
            commentView.frame = CGRect(
                origin: CGPoint(x: itemsPadding, y: nftView.frame.maxY),
                size: commentView.sizeThatFits(CGSize(width: itemsWidth, height: 0))
            )
        } else {
            commentView.frame = CGRect(
                origin: CGPoint(x: itemsPadding, y: nftView.frame.maxY),
                size: .zero
            )
        }

        if !encryptedCommentView.isHidden {
            encryptedCommentView.frame = CGRect(
                origin: CGPoint(x: itemsPadding, y: commentView.frame.maxY),
                size: encryptedCommentView.sizeThatFits(CGSize(width: itemsWidth, height: 0))
            )
        } else {
            encryptedCommentView.frame = CGRect(
                origin: CGPoint(x: itemsPadding, y: commentView.frame.maxY),
                size: .zero
            )
        }

        if !descriptionView.isHidden {
            descriptionView.frame = CGRect(
                origin: CGPoint(x: itemsPadding, y: encryptedCommentView.frame.maxY),
                size: descriptionView.sizeThatFits(CGSize(width: itemsWidth, height: 0))
            )
        } else {
            descriptionView.frame = CGRect(
                origin: CGPoint(x: itemsPadding, y: encryptedCommentView.frame.maxY),
                size: .zero
            )
        }

        separatorView.frame = CGRect(
            x: UIEdgeInsets.contentPadding.left,
            y: bounds.height - 0.5,
            width: bounds.width - UIEdgeInsets.contentPadding.left,
            height: 0.5
        )
    }

    public func prepareForReuse() {
        nftView.prepareForReuse()
    }

    func updateSeparatorVisibility() {
        let isVisible = !isHighlighted && isSeparatorVisible
        separatorView.isHidden = !isVisible
    }

    private func setup() {
        contentView.isUserInteractionEnabled = false
        commentView.isUserInteractionEnabled = false
        descriptionView.isUserInteractionEnabled = false

        separatorView.color = .Separator.common
        backgroundColor = .Background.content
        isExclusiveTouch = true

        addSubview(highlightView)
        addSubview(contentContainer)
        contentContainer.addSubview(contentView)
        contentContainer.addSubview(encryptedCommentView)
        contentContainer.addSubview(commentView)
        contentContainer.addSubview(descriptionView)
        contentContainer.addSubview(nftView)
        addSubview(separatorView)
    }
}

private extension UIEdgeInsets {
    static var contentPadding = UIEdgeInsets(top: 16, left: 16, bottom: 16, right: 16)
}
