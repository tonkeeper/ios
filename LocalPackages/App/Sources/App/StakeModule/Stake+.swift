
import Foundation
import SwiftUI
import UIKit

extension String {
    func getImage() -> UIImage? {
        switch self {
        case "bemo": return UIImage.TKUIKit.Icons.Size44.bemo
        case "nominators": return UIImage.TKUIKit.Icons.Size44.nominators
        case "tonstakers": return UIImage.TKUIKit.Icons.Size44.tonstakers
        case "whalesliquid": return UIImage.TKUIKit.Icons.Size44.whalesliquid
        case "tonwhales": return UIImage.TKUIKit.Icons.Size44.whalesliquid
            
        case "tonkeeperqueue#1": return UIImage.TKUIKit.Icons.Size44.tonkeeper
        case "tonkeeperqueue#2": return UIImage.TKUIKit.Icons.Size44.tonkeeper
            
        default:
            return nil
        }
    }
    
    func asProvider() -> String? {
        switch self {
        case "bemo": return "Bemo"
        case "nominators": return "TON Nominators"
        case "tonstakers": return "Tonstakers"
        case "whalesliquid": return "Whales Liquid Pool"
        case "tonwhales": return "TON Whales"
            
        case "tonkeeperqueue#1": return "Tonkeeper Queue #1"
        case "tonkeeperqueue#2": return "Tonkeeper Queue #2"
            
        default:
            return nil
        }
    }
}

public struct DraggingComponent: View {

    @Binding var isLocked: Bool
    let isLoading: Bool
    let maxWidth: CGFloat
    
    let main: Color
    let layer2: Color
    let mainLabel: Color
    let secondaryLabel: Color

    @State private var width = CGFloat(98)
    private  let minWidth = CGFloat(98)

    init(isLocked: Binding<Bool>, isLoading: Bool, maxWidth: CGFloat,
         main: Color, layer2: Color, mainLabel: Color, secondaryLabel: Color) {
        _isLocked = isLocked
        self.isLoading = isLoading
        self.maxWidth = maxWidth
        
        self.main = main
        self.layer2 = layer2
        self.mainLabel = mainLabel
        self.secondaryLabel = secondaryLabel
    }

    public var body: some View {
        RoundedRectangle(cornerRadius: 16)
            .fill(main)
            .frame(width: width)
            .overlay(
                Button(action: { }) {
                    ZStack {
                        image(name: "arrow.right", isShown: isLocked)
                        progressView(isShown: isLoading)
                        image(name: "checkmark", isShown: !isLocked && !isLoading)
                    }
                    .animation(.easeIn(duration: 0.35).delay(0.55), value: !isLocked && !isLoading)
                }
                .buttonStyle(BaseButtonStyle())
                .disabled(!isLocked || isLoading),
                alignment: .trailing
            )
        
            .simultaneousGesture(
                DragGesture()
                    .onChanged { value in
                        guard isLocked else { return }
                        if value.translation.width > 0 {
                            width = min(max(value.translation.width + minWidth, minWidth), maxWidth)
                        }
                    }
                    .onEnded { value in
                        guard isLocked else { return }
                        if width < maxWidth {
                            width = minWidth
                            UINotificationFeedbackGenerator().notificationOccurred(.warning)
                        } else {
                            UINotificationFeedbackGenerator().notificationOccurred(.success)
                            withAnimation(.spring().delay(0.5)) {
                                isLocked = false
                            }
                        }
                    }
            )
            .animation(.spring(response: 0.5, dampingFraction: 1, blendDuration: 0), value: width)
    }

    private func image(name: String, isShown: Bool) -> some View {
        SwiftUI.Image(systemName: name)
            .font(.system(size: 20, weight: .regular, design: .rounded))
            .foregroundColor(Color.white)
            .frame(width: 90, height: 56)
            .padding(4)
            .opacity(isShown ? 1 : 0)
            .scaleEffect(isShown ? 1 : 0.01)
    }

    private func progressView(isShown: Bool) -> some View {
        ProgressView()
            .progressViewStyle(.circular)
            .foregroundColor(.white)
            .opacity(isShown ? 1 : 0)
            .scaleEffect(isShown ? 1 : 0.01)
    }
}

public struct BackgroundComponent: View {
    let color: Color
    let secondaryLabel: Color
    init(color: Color, secondaryLabel: Color) {
        self.color = color
        self.secondaryLabel = secondaryLabel
    }

    public var body: some View {
        ZStack(alignment: .leading)  {
            RoundedRectangle(cornerRadius: 16)
                .fill(color)

            Text("Slide to confirm")
                .font(.callout.weight(.regular))
                .bold()
                .foregroundColor(secondaryLabel)
                .frame(maxWidth: .infinity)
        }
    }

}

public struct BaseButtonStyle: ButtonStyle {
    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1)
            .opacity(configuration.isPressed ? 0.9 : 1)
            .animation(.default, value: configuration.isPressed)
    }
}
