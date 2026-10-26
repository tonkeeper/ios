import AppUI
import SwiftUI
import TKUIKit

final class MoonPayPaymentStatusViewController: TKHostingController<MoonPayPaymentStatusContent> {
    private let viewModel: MoonPayPaymentStatusViewModel

    init(viewModel: MoonPayPaymentStatusViewModel) {
        self.viewModel = viewModel
        super.init(content: MoonPayPaymentStatusContent(viewModel: viewModel))
    }

    @available(*, unavailable)
    @MainActor
    dynamic required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .Background.page
        viewModel.start()
    }
}

struct MoonPayPaymentStatusContent: View {
    @ObservedObject var viewModel: MoonPayPaymentStatusViewModel

    var body: some View {
        MoonPayPaymentStatusView(
            state: viewModel.screenState,
            onAction: viewModel.tapAction,
            onClose: viewModel.close,
            onCopy: viewModel.copy
        )
    }
}
