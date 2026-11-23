import AppUI
import SwiftUI
import TKUIKit

struct MoonPayPaymentStatusContent: View {
    @ObservedObject var viewModel: MoonPayPaymentStatusViewModel

    var body: some View {
        MoonPayPaymentStatusView(
            state: viewModel.screenState,
            onAction: viewModel.tapAction,
            onCopy: viewModel.copy
        )
    }
}
