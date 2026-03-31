import SwiftUI

public extension Text {
    func textStyle(_ textStyle: TKTextStyle) -> some View {
        self
            .font(Font(textStyle.font))
            .baselineOffset(textStyle.baselineOffset)
            .lineSpacing(textStyle.lineSpacing)
    }
}
