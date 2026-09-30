import SnapKit
import SwiftUI
import UIKit

final class WalletBalanceCollectiblesContainerView: UIView {
    private let hostingView = SwiftUIHostingView()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(viewModel: WalletBalanceMultichainCollectiblesViewModel) {
        hostingView.setContent(id: viewModel.wallet.id) {
            WalletBalanceMultichainCollectiblesView(viewModel: viewModel)
        }
    }

    private func setup() {
        addSubview(hostingView)
        hostingView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
    }
}
