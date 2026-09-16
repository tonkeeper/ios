import SwiftUI
import TKUIKit

struct PerpsCircleButton: View {
    let icon: UIImage
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            SwiftUI.Image(uiImage: icon)
                .renderingMode(.template)
                .foregroundStyle(.iconSecondary)
                .frame(width: 32, height: 32)
                .background(.backgroundContentTint)
                .clipShape(Circle())
        }
    }
}
