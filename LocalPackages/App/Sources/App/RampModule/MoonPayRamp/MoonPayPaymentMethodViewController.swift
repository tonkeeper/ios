import AppUI
import SwiftUI
import TKUIKit

final class MoonPayPaymentMethodViewController: TKHostingController<MoonPayPaymentMethodContent> {
    private let viewModel: MoonPayPaymentMethodViewModel

    init(viewModel: MoonPayPaymentMethodViewModel) {
        self.viewModel = viewModel
        super.init(content: MoonPayPaymentMethodContent(viewModel: viewModel))
    }

    @available(*, unavailable)
    @MainActor
    dynamic required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .Background.page
    }
}

struct MoonPayPaymentMethodContent: View {
    @ObservedObject var viewModel: MoonPayPaymentMethodViewModel

    var body: some View {
        MoonPayPaymentMethodView(
            state: viewModel.screenState,
            onSelect: viewModel.select,
            onCryptoDeposit: viewModel.cryptoDeposit,
            onBack: viewModel.back,
            onClose: viewModel.close
        )
    }
}
