import SwiftUI
import WidgetKit
import KeeperCore

struct HomeScreenBalanceWidget<Content: View>: View {
  let entry: BalanceWidgetEntry
  var content: (_ model: BalanceWidgetController.Model) -> Content
  
  init(entry: BalanceWidgetEntry,
       @ViewBuilder content: @escaping (_ model: BalanceWidgetController.Model) -> Content) {
    self.entry = entry
    self.content = content
  }
  
  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      HStack {
        Spacer()
        TonIconView()
      }
      Spacer()
      switch entry.loadResult {
      case .success(let success):
        content(success)
      case .failure(let failure):
        failureView(error: failure)
      }
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    .padding(EdgeInsets(top: 12, leading: 16, bottom: 12, trailing: 16))
    .widgetBackground(backgroundView: Color(UIColor.Background.page))
  }
  
  @ViewBuilder
  private func failureView(error: BalanceWidgetController.Error) -> some View {
    switch error {
    case .noWallet:
      Text("Create a new wallet or import an existing one")
        .font(.system(size: 13, weight: .regular))
        .foregroundColor(Color(.Text.secondary))
    case .failedToLoad:
      Text("Failed to load balance. Check your internet connection.")
        .font(.system(size: 13, weight: .regular))
        .foregroundColor(Color(.Text.secondary))
    }
  }
}
