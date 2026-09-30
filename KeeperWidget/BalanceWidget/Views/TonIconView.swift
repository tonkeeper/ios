import SwiftUI
import TKUIKit

struct TonIconView: View {
    var body: some View {
        SwiftUI.Image.TKUIKit.Icons.Size24.tonIcon
            .resizable()
            .frame(width: 24, height: 24)
    }
}
