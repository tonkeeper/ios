import SwiftUI

public extension Text {
  func textStyle(_ textStyle: TKTextStyle) -> some View {
    self
      .font(Font(textStyle.font))
      .lineSpacing(textStyle.lineSpacing)
  }
}
