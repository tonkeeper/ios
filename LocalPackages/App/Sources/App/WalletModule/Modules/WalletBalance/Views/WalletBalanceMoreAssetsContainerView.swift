import SnapKit
import SwiftUI
import TKUIKit
import UIKit

final class WalletBalanceMoreAssetsContainerView: UIView {
    private let hostingView = SwiftUIHostingView()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(previewAvatars: [AssetAvatarViewImageSource]) {
        hostingView.setContent {
            WalletBalanceMoreAssetsCell(
                previewAvatars: previewAvatars,
                showsDivider: false,
                action: nil
            )
        }
    }

    override func sizeThatFits(_ size: CGSize) -> CGSize {
        CGSize(width: size.width, height: Layout.rowHeight)
    }

    private enum Layout {
        static let rowHeight: CGFloat = 56
    }

    private func setup() {
        isUserInteractionEnabled = false
        hostingView.isUserInteractionEnabled = false
        addSubview(hostingView)
        hostingView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
    }
}
