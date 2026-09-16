import SnapKit
import SwiftUI
import TKUIKit
import UIKit

final class WalletsListRaffleBannerContainerView: UIView {
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
        banner: WalletsListRaffleBanner,
        onTap: @escaping () -> Void,
        onDismiss: @escaping () -> Void
    ) {
        hostingView.setContent(id: banner.id) {
            BannerItemView(
                item: BannerItem(
                    id: banner.id,
                    title: banner.title,
                    description: banner.description,
                    actionTitle: banner.actionTitle,
                    imageURL: banner.imageURL,
                    action: onTap
                ),
                height: Layout.bannerHeight,
                onTapDismiss: onDismiss
            )
            .padding(.horizontal, Layout.horizontalPadding)
            .padding(.bottom, Layout.bottomPadding)
        }
    }

    private func setup() {
        addSubview(hostingView)
        hostingView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
    }
}

private extension WalletsListRaffleBannerContainerView {
    enum Layout {
        static let bannerHeight: CGFloat = 90
        static let horizontalPadding: CGFloat = 16
        static let bottomPadding: CGFloat = 16
    }
}
