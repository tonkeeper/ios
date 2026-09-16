import SwiftUI

public struct BatterySwiftUIViewPreviews: View {
    public init() {}

    private let sections: [Section] = [
        Section(title: "Empty", state: .empty),
        Section(title: "Empty tinted", state: .emptyTinted),
        Section(title: "Negative", state: .negative),
        Section(title: "10%", state: .fill(0.1)),
        Section(title: "50%", state: .fill(0.5)),
        Section(title: "100%", state: .fill(1)),
    ]

    private let sizes: [BatterySwiftUIViewConfig.Size] = [
        .size24,
        .size34,
        .size44,
        .size52,
        .size128,
    ]

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                ForEach(sections, id: \.self) { section in
                    VStack(alignment: .leading, spacing: 12) {
                        Text(section.title)
                            .textStyle(.label1)
                            .foregroundStyle(.textPrimary)

                        HStack(alignment: .bottom, spacing: 20) {
                            ForEach(sizes, id: \.self) { size in
                                BatterySwiftUIView(config: BatterySwiftUIViewConfig(
                                    size: size,
                                    state: section.state
                                ))
                            }
                        }
                    }
                }

                BatterySwiftUIView(config: BatterySwiftUIViewConfig(
                    size: .size34,
                    state: .empty,
                    padding: BatterySwiftUIViewConfig.Padding(
                        top: 10,
                        leading: 0,
                        bottom: 12,
                        trailing: 8
                    )
                ))
            }
            .padding(.all, 16)
        }
        .tkImmediateButtonPresses()
        .debugPreview()
    }
}

private extension BatterySwiftUIViewPreviews {
    struct Section: Hashable {
        let title: String
        let state: BatterySwiftUIViewConfig.State
    }
}

#Preview("Deep Blue") {
    BatterySwiftUIViewPreviews()
        .tkPreviewTheme(.deepBlue)
}
