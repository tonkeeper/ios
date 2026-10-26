import SwiftUI
import TKUIKit

/// The orbit: three rings, one icon per chain on the middle one and the logo above them. With a
/// `timeline` it moves — the icons fly out from under the logo, the orbit turns while loading and
/// settles before the added icons colour in. Without one (reduced motion) it stands in its resting
/// layout with the result applied.
struct NewNetworksOrbitView: View {
    let chains: [NewNetworksScreenState.Chain]
    /// The chains that got added: coloured once the orbit settles.
    let addedIds: Set<String>
    let timeline: NewNetworksOrbitTimeline?
    let isPaused: Bool
    let scale: CGFloat

    var body: some View {
        TimelineView(.animation(paused: isPaused)) { context in
            orbit(at: context.date)
        }
        .frame(width: NewNetworksMotion.orbitSize * scale, height: NewNetworksMotion.orbitSize * scale)
    }
}

private extension NewNetworksOrbitView {
    struct Ring {
        let diameter: CGFloat
        let opacity: Double
        let breathes: Bool
    }

    static let rings = [
        Ring(diameter: 368, opacity: 0.5, breathes: false),
        Ring(diameter: 272, opacity: 0.75, breathes: true),
        Ring(diameter: 176, opacity: 1, breathes: true),
    ]

    func orbit(at date: Date) -> some View {
        let rotation = timeline?.rotation(at: date) ?? 0
        let iconSize = NewNetworksMotion.iconSize(count: chains.count) * scale
        let radius = NewNetworksMotion.iconOrbitRadius * scale
        return ZStack {
            rings(progress: timeline?.rings(at: date) ?? 1, breathing: timeline?.breathing(at: date) ?? 1)

            ForEach(Array(chains.enumerated()), id: \.element.id) { index, chain in
                icon(chain, index: index, rotation: rotation, radius: radius, size: iconSize, at: date)
            }

            // Above the icons: they fly out from under it.
            SwiftUI.Image.TKUIKit.Icons.Size128.logo
                .renderingMode(.template)
                .resizable()
                .foregroundStyle(.iconPrimary)
                .frame(width: NewNetworksMotion.logoSize * scale, height: NewNetworksMotion.logoSize * scale)
                .scaleEffect(timeline?.logoScale(at: date) ?? 1)
        }
    }

    func rings(progress: Double, breathing: Double) -> some View {
        let ringScale = 0.6 + 0.4 * progress
        return ForEach(Self.rings.indices, id: \.self) { index in
            let ring = Self.rings[index]
            let diameter = ring.diameter * scale * ringScale * (ring.breathes ? breathing : 1)
            Circle()
                .strokeBorder(TKColor.separatorCommon.opacity(ring.opacity * progress), lineWidth: 1)
                .frame(width: diameter, height: diameter)
        }
    }

    func icon(
        _ chain: NewNetworksScreenState.Chain,
        index: Int,
        rotation: Double,
        radius: CGFloat,
        size: CGFloat,
        at date: Date
    ) -> some View {
        let fly = timeline?.fly(index: index, count: chains.count, at: date) ?? 1
        let isAdded = addedIds.contains(chain.id)
        let colored = isAdded ? timeline?.colored(at: date) ?? 1 : 0
        let pop = isAdded ? timeline?.pop(at: date) ?? 1 : 1
        let angle = (NewNetworksMotion.firstIconAngle + Double(index) * 360 / Double(chains.count) + rotation) * .pi / 180
        let borderWidth = NewNetworksMotion.iconBorderWidth * scale
        return ZStack {
            if colored > 0 {
                NewNetworksChainIcon(chain: chain, style: .colored, size: size, borderWidth: borderWidth)
            }
            NewNetworksChainIcon(chain: chain, style: .grey, size: size, borderWidth: borderWidth)
                .opacity(min(1, fly * 2) * (1 - colored))
                .modifier(FlyOutBlur(radius: NewNetworksMotion.flyOutBlurRadius * (1 - fly) * scale))
        }
        .scaleEffect((0.3 + 0.7 * fly) * pop)
        .offset(x: cos(angle) * radius * fly, y: sin(angle) * radius * fly)
    }
}

/// A blur only while an icon is still flying out: a zero-radius blur would still cost a pass per frame.
private struct FlyOutBlur: ViewModifier {
    let radius: CGFloat

    func body(content: Content) -> some View {
        if radius > 0.01 {
            content.blur(radius: radius)
        } else {
            content
        }
    }
}
