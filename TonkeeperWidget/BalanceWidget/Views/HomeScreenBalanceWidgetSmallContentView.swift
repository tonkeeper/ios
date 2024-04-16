import SwiftUI
import TKUIKit
import KeeperCore

struct HomeScreenBalanceWidgetSmallContentView: View {
  let model: BalanceWidgetController.Model
  
  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      Text(model.tonBalance + " TON")
        .font(.system(size: 13, weight: .medium))
        .foregroundColor(Color(.Accent.blue))
        .padding(.bottom, 4)
        .scaledToFit()
        .minimumScaleFactor(0.3)
      Text(model.fiatBalance)
        .font(.system(size: 32, weight: .medium))
        .foregroundColor(Color(.Text.primary))
        .padding(.bottom, 16)
        .scaledToFit()
        .minimumScaleFactor(0.3)
      Text(model.address)
        .font(.system(size: 13, weight: .regular))
        .foregroundColor(Color(.Text.tertiary))
    }
  }
}
