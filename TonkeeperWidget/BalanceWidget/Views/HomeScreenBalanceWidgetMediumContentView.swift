import SwiftUI
import KeeperCore

struct HomeScreenBalanceWidgetMediumContentView: View {
  let model: BalanceWidgetController.Model
  
  var body: some View {
    HStack(alignment: .bottom, spacing: 0) {
      VStack(alignment: .leading, spacing: 0) {
        Text("Available")
        Text(model.tonBalance + " TON")
          .padding(.bottom, 4)
          .scaledToFit()
          .minimumScaleFactor(0.3)
      }
      .font(.system(size: 13, weight: .medium))
      .foregroundColor(Color(.Accent.blue))
      Spacer()
      VStack(alignment: .trailing, spacing: 0) {
        Text(model.fiatBalance)
          .font(.system(size: 32, weight: .medium))
          .foregroundColor(Color(.Text.primary))
          .scaledToFit()
          .minimumScaleFactor(0.3)
        Text(model.address)
          .font(.system(size: 13, weight: .regular))
          .foregroundColor(Color(.Text.tertiary))
      }
    }
  }
}
