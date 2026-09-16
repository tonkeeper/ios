import SwiftUI

struct RoundedRectExt: Shape {
    var radius: CGFloat
    var corners: UIRectCorner

    init(
        radius: CGFloat,
        corners: UIRectCorner = .allCorners
    ) {
        self.radius = radius
        self.corners = corners
    }

    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(
            roundedRect: rect,
            byRoundingCorners: corners,
            cornerRadii: CGSize(
                width: radius,
                height: radius
            )
        )
        return Path(path.cgPath)
    }
}
