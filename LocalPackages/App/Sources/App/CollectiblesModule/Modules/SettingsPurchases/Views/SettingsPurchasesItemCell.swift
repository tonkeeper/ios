import TKUIKit
import UIKit

final class SettingsPurchasesItemCell: TKCollectionViewNewCell, ConfigurableView {
    let control = SettingsPurchasesItemControl()
    let listView = TKListItemContentView()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    struct Model {
        let controlModel: SettingsPurchasesItemControl.Model?
        let listItemConfiguration: TKListItemContentView.Configuration
        let accessory: TKListItemAccessory?
        let tapHandler: (() -> Void)?
    }

    func configure(model: Model) {
        if let controlModel = model.controlModel {
            control.configure(model: controlModel)
            control.isHidden = false
        } else {
            control.isHidden = true
        }
        listView.configuration = model.listItemConfiguration

        if let accessory = model.accessory {
            accessoryViews = [accessory.view]
        } else {
            accessoryViews = []
        }

        setNeedsLayout()
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        listView.prepareForReuse()
    }

    override func contentSize(targetWidth: CGFloat) -> CGSize {
        let listItemWidth: CGFloat = {
            if control.isHidden {
                return targetWidth
            } else {
                let controlSize = control.sizeThatFits(CGSize(width: targetWidth, height: 0))
                return targetWidth - .padding - controlSize.width
            }
        }()
        let listItemSize = listView.sizeThatFits(CGSize(width: listItemWidth, height: 0))
        return CGSize(width: targetWidth, height: listItemSize.height)
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        var listOriginX: CGFloat = 0
        var listWidth: CGFloat = 0
        if control.isHidden {
            control.frame = .zero
            listWidth = contentContainerView.bounds.width
        } else {
            let controlSize = control.sizeThatFits(CGSize(width: 0, height: 0))
            control.frame = CGRect(origin: .zero, size: CGSize(width: controlSize.width, height: contentContainerView.bounds.height))
            listOriginX += .padding + control.frame.maxX
            listWidth = contentContainerView.bounds.width - .padding - controlSize.width
        }
        let listItemSize = listView.sizeThatFits(CGSize(width: listWidth, height: 0))
        listView.frame = CGRect(origin: CGPoint(x: listOriginX, y: 0), size: listItemSize)
    }
}

private extension SettingsPurchasesItemCell {
    func setup() {
        backgroundColor = .Background.content
        hightlightColor = .Background.highlighted
        contentViewPadding = .init(top: 16, left: 16, bottom: 16, right: 16)
        contentContainerView.addSubview(control)
        contentContainerView.addSubview(listView)
    }
}

private extension CGFloat {
    static let padding: CGFloat = 16
    static let listItemHeight: CGFloat = 52
}
