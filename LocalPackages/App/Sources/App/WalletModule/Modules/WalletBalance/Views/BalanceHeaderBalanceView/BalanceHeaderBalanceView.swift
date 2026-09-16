import SnapKit
import SwiftUI
import TKUIKit
import UIKit

final class BalanceHeaderBalanceView: UIView, ConfigurableView {
    private let hostingView = SwiftUIHostingView()
    private let store = BalanceHeaderBalanceViewStore()
    private var walletIdentifier: String?

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    struct Model {
        let walletIdentifier: String
        let config: BalanceViewConfig
        let balanceAction: (() -> Void)?
        let addressAction: (() -> Void)?
        let batteryAction: (() -> Void)?
        let backupAction: (() -> Void)?

        init(
            walletIdentifier: String,
            config: BalanceViewConfig,
            balanceAction: (() -> Void)? = nil,
            addressAction: (() -> Void)? = nil,
            batteryAction: (() -> Void)? = nil,
            backupAction: (() -> Void)? = nil
        ) {
            self.walletIdentifier = walletIdentifier
            self.config = config
            self.balanceAction = balanceAction
            self.addressAction = addressAction
            self.batteryAction = batteryAction
            self.backupAction = backupAction
        }
    }

    func configure(model: Model) {
        let animatesAmountUpdates = walletIdentifier.map { $0 == model.walletIdentifier } ?? false
        walletIdentifier = model.walletIdentifier
        store.state = BalanceHeaderBalanceViewState(
            model: model,
            animatesAmountUpdates: animatesAmountUpdates
        )
    }
}

private extension BalanceHeaderBalanceView {
    func setup() {
        hostingView.setContent {
            BalanceHeaderBalanceContentView(store: store)
        }

        addSubview(hostingView)
        setupConstraints()
    }

    func setupConstraints() {
        snp.makeConstraints { make in
            make.height.equalTo(BalanceSwiftUIView.height)
        }

        hostingView.snp.makeConstraints { make in
            make.edges.equalTo(self)
        }
    }
}

private final class BalanceHeaderBalanceViewStore: ObservableObject {
    @Published var state = BalanceHeaderBalanceViewState(
        model: BalanceHeaderBalanceView.Model(
            walletIdentifier: "",
            config: .shimmer
        ),
        animatesAmountUpdates: false
    )
}

private struct BalanceHeaderBalanceViewState {
    let model: BalanceHeaderBalanceView.Model
    let animatesAmountUpdates: Bool
}

private struct BalanceHeaderBalanceContentView: View {
    @ObservedObject var store: BalanceHeaderBalanceViewStore

    var body: some View {
        BalanceSwiftUIView(
            config: store.state.model.config,
            animatesAmountUpdates: store.state.animatesAmountUpdates,
            balanceAction: store.state.model.balanceAction,
            addressAction: store.state.model.addressAction,
            batteryAction: store.state.model.batteryAction,
            backupAction: store.state.model.backupAction
        )
    }
}
