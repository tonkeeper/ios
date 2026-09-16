import SwiftUI

public struct QrCodeStyle {
    public var moduleColor: Color
    public var finderPatternColor: Color

    public init(
        moduleColor: Color = .black,
        finderPatternColor: Color = .black
    ) {
        self.moduleColor = moduleColor
        self.finderPatternColor = finderPatternColor
    }
}
