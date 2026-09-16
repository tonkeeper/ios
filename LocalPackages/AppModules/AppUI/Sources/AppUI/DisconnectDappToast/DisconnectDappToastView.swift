import SwiftUI
import TKUIKit

struct DisconnectDappToastView: View {
    @Environment(\.tkPalette) private var palette

    let text: String
    let buttonTitle: String
    let buttonAction: () -> Void

    var body: some View {
        HStack(spacing: 20) {
            Text(text)
                .foregroundStyle(.textPrimary)
                .textStyle(TKTextStyle.body2)
                .multilineTextAlignment(.leading)
            Spacer()
            Button(action: buttonAction) {
                Text(buttonTitle)
                    .foregroundStyle(.accentRed)
                    .textStyle(TKTextStyle.label2)
                    .frame(maxHeight: .infinity)
            }
            .fixedSize(horizontal: true, vertical: false)
            .frame(maxHeight: .infinity)
        }
        .fixedSize(horizontal: false, vertical: true)
        .padding(EdgeInsets(top: 17, leading: 20, bottom: 16, trailing: 20))
        .background(.backgroundContent)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: palette.constant.black.opacity(0.04), radius: 4, x: 0, y: 4)
    }
}
