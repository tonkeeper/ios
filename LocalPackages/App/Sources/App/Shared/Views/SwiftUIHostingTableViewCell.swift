import SnapKit
import SwiftUI
import UIKit

final class SwiftUIHostingTableViewCell: UITableViewCell {
    enum GroupPosition {
        case single
        case first
        case middle
        case last

        init(index: Int, count: Int) {
            switch (index, count) {
            case (_, 0):
                self = .middle
            case (_, 1):
                self = .single
            case (0, _):
                self = .first
            case let (index, count) where index == count - 1:
                self = .last
            default:
                self = .middle
            }
        }

        var maskedCorners: CACornerMask {
            switch self {
            case .single:
                [
                    .layerMinXMinYCorner,
                    .layerMaxXMinYCorner,
                    .layerMinXMaxYCorner,
                    .layerMaxXMaxYCorner,
                ]
            case .first:
                [
                    .layerMinXMinYCorner,
                    .layerMaxXMinYCorner,
                ]
            case .middle:
                []
            case .last:
                [
                    .layerMinXMaxYCorner,
                    .layerMaxXMaxYCorner,
                ]
            }
        }
    }

    private let hostingView = SwiftUIHostingView()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setup()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        applyGroupedBackground(nil)
        hostingView.setContent {
            EmptyView()
        }
    }

    func setContent<ID: Hashable, Content: View>(
        id: ID,
        @ViewBuilder _ content: () -> Content
    ) {
        hostingView.setContent(id: id, content)
    }

    func applyGroupedBackground(
        _ position: GroupPosition?,
        backgroundColor: UIColor = .Background.content,
        cornerRadius: CGFloat = 16
    ) {
        contentView.backgroundColor = position == nil ? .clear : backgroundColor

        guard let position else {
            contentView.layer.cornerRadius = 0
            contentView.layer.maskedCorners = []
            contentView.layer.masksToBounds = false
            return
        }

        let maskedCorners = position.maskedCorners
        contentView.layer.cornerCurve = .continuous
        contentView.layer.cornerRadius = maskedCorners.isEmpty ? 0 : cornerRadius
        contentView.layer.maskedCorners = maskedCorners
        contentView.layer.masksToBounds = !maskedCorners.isEmpty
    }
}

private extension SwiftUIHostingTableViewCell {
    func setup() {
        backgroundColor = .clear
        contentView.backgroundColor = .clear
        selectionStyle = .none

        contentView.addSubview(hostingView)
        hostingView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
    }
}
