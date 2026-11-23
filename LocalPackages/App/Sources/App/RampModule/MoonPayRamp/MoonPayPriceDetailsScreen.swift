import AppUI
import SwiftUI

struct MoonPayPriceDetailsScreen: View {
    @ObservedObject var viewModel: MoonPayRampViewModel
    /// The first frame's rows, before the view model has reported.
    let opened: MoonPayPriceDetailsViewState
    /// The screen no longer has a quote to break down: a limit error, a reset or a reload.
    let onUnavailable: () -> Void
    /// The rows last shown: the sheet keeps them while it slides out.
    @State private var last: MoonPayPriceDetailsViewState?

    var body: some View {
        let state = viewModel.priceDetailsState
        MoonPayPriceDetailsView(state: state ?? last ?? opened, onToggleRateDirection: viewModel.toggleRateDirection)
            .onChange(of: state) { newValue in
                if let newValue {
                    last = newValue
                } else {
                    onUnavailable()
                }
            }
            .onAppear {
                if let state {
                    last = state
                } else {
                    onUnavailable()
                }
            }
    }
}
