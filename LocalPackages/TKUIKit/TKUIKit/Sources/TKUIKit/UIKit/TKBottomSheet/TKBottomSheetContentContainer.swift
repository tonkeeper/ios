import SwiftUI

/// Pins bottom sheet content to the top of the frame the sheet hands its content controller.
///
/// That frame is taller than the content itself — it includes the reserved bottom safe area, and
/// grows further while the sheet is dragged upwards — and a hosting controller centers a root view
/// that does not fill its bounds, so without this the content drifts down as the frame grows.
///
/// The sheet measures the bare content, so the content has to render at the height it was measured
/// at: without the ideal height pinned, the unbounded proposal below lets text render fewer lines
/// than the measurement counted, leaving dead space at the bottom of the sheet.
public struct TKBottomSheetContentContainer<Content: View>: View {
    private let content: Content

    init(content: Content) {
        self.content = content
    }

    public var body: some View {
        content
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxHeight: .infinity, alignment: .top)
    }
}
