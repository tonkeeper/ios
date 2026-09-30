import SnapKit
import SwiftUI
import UIKit

final class WalletBalanceHomeBannersContainerView: UIView {
    private let hostingView = SwiftUIHostingView()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(viewModel: WalletBalanceHomeBannersViewModel) {
        hostingView.setContent(id: viewModel.wallet.id) {
            WalletBalanceHomeBannersUIKitView(viewModel: viewModel)
        }
    }

    private func setup() {
        clipsToBounds = true
        addSubview(hostingView)
        hostingView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
    }
}
