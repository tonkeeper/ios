import SnapKit
import SwiftUI
import TKUIKit
import UIKit

final class WalletBalanceCryptoAssetsSectionHeaderContainerView: UIView {
    private let hostingView = SwiftUIHostingView()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(
        canManage: Bool,
        onTapOpenAssets: @escaping () -> Void,
        onTapManage: @escaping () -> Void
    ) {
        hostingView.setContent {
            WalletBalanceCryptoAssetsSectionHeaderView(
                canManage: canManage,
                onTapOpenAssets: onTapOpenAssets,
                onTapManage: onTapManage
            )
        }
    }

    private func setup() {
        addSubview(hostingView)
        hostingView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
    }
}
