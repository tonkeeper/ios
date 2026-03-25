import UIKit

public final class TKActionLabel: UILabel {
    public struct ActionItem: Equatable {
        let id = UUID()
        let text: String
        let action: () -> Void

        public static func == (lhs: ActionItem, rhs: ActionItem) -> Bool {
            lhs.id == rhs.id
        }

        public init(
            text: String,
            action: @escaping () -> Void
        ) {
            self.text = text
            self.action = action
        }
    }

    private var actionItems = [ActionItem]()
    private var touchedActionItem: ActionItem?

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    public func setAttributedText(
        _ attributedText: NSAttributedString,
        actionItems: [ActionItem]
    ) {
        guard let mutable = attributedText.mutableCopy() as? NSMutableAttributedString else { return }
        for item in actionItems {
            let range = (mutable.string as NSString).range(of: item.text)
            mutable.addAttribute(.foregroundColor, value: UIColor.Accent.blue, range: range)
        }
        self.attributedText = mutable
        self.actionItems = actionItems
    }

    override public func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first,
              let item = getActionItem(touch: touch) else { return }
        self.touchedActionItem = item
        setColor(touches: touches, color: .Accent.blue.withAlphaComponent(0.7))
    }

    override public func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        resetColors()
        if let touch = touches.first,
           let item = getActionItem(touch: touch),
           item == self.touchedActionItem
        {
            item.action()
        }
        self.touchedActionItem = nil
    }

    override public func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        resetColors()
        if let touch = touches.first,
           let item = getActionItem(touch: touch),
           item == self.touchedActionItem
        {
            item.action()
        }
        self.touchedActionItem = nil
    }

    private func getActionItem(touch: UITouch) -> ActionItem? {
        let location = touch.location(in: self)
        let offset: CGFloat = 20
        let deltas = [
            CGPoint(x: -offset, y: 0),
            CGPoint(x: 0, y: -offset),
            CGPoint(x: -offset, y: -offset),
            CGPoint(x: offset, y: 0),
            CGPoint(x: 0, y: offset),
            CGPoint(x: offset, y: offset),
        ]
        let locations = deltas.map {
            CGPoint(x: location.x + $0.x, y: location.y + $0.y)
        }
        for location in locations {
            guard let item = getActionItem(location: location) else { continue }
            return item
        }
        return nil
    }

    private func setup() {
        isUserInteractionEnabled = true
    }

    private func resetColors() {
        guard let mutable = attributedText?.mutableCopy() as? NSMutableAttributedString else { return }
        for item in actionItems {
            let range = (mutable.string as NSString).range(of: item.text)
            mutable.addAttribute(.foregroundColor, value: UIColor.Accent.blue, range: range)
        }
        self.attributedText = mutable
        attributedText = mutable
    }

    private func setColor(
        touches: Set<UITouch>,
        color: UIColor
    ) {
        guard let mutable = attributedText?.mutableCopy() as? NSMutableAttributedString else { return }
        guard let location = touches.first?.location(in: self),
              let item = getActionItem(location: location),
              let string = attributedText?.string else { return }
        let range = (string as NSString).range(of: item.text)
        mutable.addAttribute(.foregroundColor, value: color.cgColor, range: range)
        attributedText = mutable
    }

    private func getActionItem(location: CGPoint) -> ActionItem? {
        guard let attributedText = attributedText else {
            return nil
        }

        let textContainer = NSTextContainer(size: bounds.size)
        textContainer.lineFragmentPadding = 0.0
        textContainer.lineBreakMode = lineBreakMode
        textContainer.maximumNumberOfLines = numberOfLines

        let layoutManager = NSLayoutManager()
        layoutManager.addTextContainer(textContainer)

        let textStorage = NSTextStorage(attributedString: attributedText)
        textStorage.addAttribute(
            NSAttributedString.Key.font,
            value: font ?? .systemFont(ofSize: 10),
            range: NSMakeRange(0, attributedText.length)
        )
        textStorage.addLayoutManager(layoutManager)

        let textBoundingBox = layoutManager.usedRect(for: textContainer)
        var alignmentOffset: CGFloat!
        switch textAlignment {
        case .left, .natural, .justified:
            alignmentOffset = 0.0
        case .center:
            alignmentOffset = 0.5
        case .right:
            alignmentOffset = 1.0
        @unknown default:
            alignmentOffset = 0
        }
        let xOffset = ((bounds.size.width - textBoundingBox.size.width) * alignmentOffset) - textBoundingBox.origin.x
        let yOffset = ((bounds.size.height - textBoundingBox.size.height) * alignmentOffset) - textBoundingBox.origin.y
        let locationOfTouchInTextContainer = CGPoint(x: location.x - xOffset, y: location.y - yOffset)

        let characterIndex = layoutManager.characterIndex(for: locationOfTouchInTextContainer, in: textContainer, fractionOfDistanceBetweenInsertionPoints: nil)

        for item in actionItems {
            let range = ((text ?? "") as NSString).range(of: item.text)
            if range.contains(characterIndex) {
                return item
            }
        }
        return nil
    }
}
