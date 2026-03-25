import SwiftUI
import TKUIKit

struct DisconnectDappToastView: View {
    let text: String
    let buttonTitle: String
    let buttonAction: () -> Void

    var body: some View {
        HStack(spacing: 20) {
            Text(text)
                .foregroundColor(Color(UIColor.Text.primary))
                .textStyle(TKTextStyle.body2)
                .multilineTextAlignment(.leading)
            Spacer()
            Button(action: buttonAction) {
                Text(buttonTitle)
                    .foregroundColor(Color(UIColor.Accent.red))
                    .textStyle(TKTextStyle.label2)
                    .frame(maxHeight: .infinity)
            }
            .fixedSize(horizontal: true, vertical: false)
            .frame(maxHeight: .infinity)
        }
        .fixedSize(horizontal: false, vertical: true)
        .padding(EdgeInsets(top: 18, leading: 20, bottom: 18, trailing: 20))
        .background(Color(UIColor.Background.content))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: Color(UIColor.Constant.black).opacity(0.04), radius: 4, x: 0, y: 4)
    }
}
