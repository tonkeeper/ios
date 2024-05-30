import Foundation
import SwiftUI

extension View {
    func hideKeyboard() {
        let resign = #selector(UIResponder.resignFirstResponder)
        UIApplication.shared.sendAction(resign, to: nil, from: nil, for: nil)
    }
}

struct HeaderView<Content: View, Left: View, Right: View>: View {
    private var content: () -> Content
    private var left: (()->Left)?
    private var right: (()->Right)?
    
    private init(
        @ViewBuilder content: @escaping () -> Content,
        left: (() -> Left)?,
        right: (() -> Right)?
    ){
        self.content = content
        self.left = left
        self.right = right
    }
    
    var body: some View {
        // simplified body
        HStack{
            if let left {
                left()
                Spacer()
            }
            content()
            if let right {
                Spacer()
                right()
            }
        }
    }
}


extension HeaderView {
    init(@ViewBuilder content: @escaping () -> Content, @ViewBuilder left: @escaping () -> Left, @ViewBuilder right: @escaping () -> Right){
        self.content = content
        self.left = left
        self.right = right
    }
    
    init(@ViewBuilder content: @escaping () -> Content, @ViewBuilder left: @escaping () -> Left) where Right == EmptyView{
        self.init(content: content, left: left, right: nil)
    }
    
    init(@ViewBuilder content: @escaping () -> Content, @ViewBuilder right: @escaping () -> Right) where Left == EmptyView{
        self.init(content: content, left: nil, right: right)
    }
}


struct BigButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) var isEnabled
    var backgroundColor: Color = .blue
    var textColor: Color = .white
    var cornerRadius: CGFloat = 10
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline.bold())
            .frame(maxWidth: .infinity)
            .padding()
            .background(backgroundColor)
            .foregroundColor(textColor)
            .cornerRadius(cornerRadius)
            .saturation(isEnabled ? 1 : 0)
    }
}


struct DynamicFontSizeTextField: UIViewRepresentable {
    @Binding var text: String
    var maxLength: Int

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeUIView(context: Context) -> UITextField {
        let textField = UITextField()
        textField.delegate = context.coordinator
        textField.text = text
        textField.font = UIFont.systemFont(ofSize: DynamicFontSizeTextField.dynamicSize(text))
        textField.textColor = UIColor.white
        textField.textAlignment = .center
        textField.keyboardType = .decimalPad
        textField.addTarget(context.coordinator, action: #selector(Coordinator.textFieldDidChange(_:)), for: .editingChanged)
        return textField
    }

    func updateUIView(_ uiView: UITextField, context: Context) {
        if text.isEmpty {
            text = "0"
        }
        
        uiView.text = text
        uiView.font = UIFont.systemFont(ofSize: DynamicFontSizeTextField.dynamicSize(text))
    }
    
    static func dynamicSize(_ text: String) -> CGFloat {
        switch text.count {
        case 0...5:
            return 36
        case 6...8:
            return 34
        case 9...12:
            return 28
        case 13...15:
            return 24
        default:
            return 18
        }
    }

    class Coordinator: NSObject, UITextFieldDelegate {
        var parent: DynamicFontSizeTextField

        init(parent: DynamicFontSizeTextField) {
            self.parent = parent
        }

        @objc func textFieldDidChange(_ textField: UITextField) {
            let newText = textField.text ?? ""
            if newText.count > parent.maxLength {
                textField.text = String(newText.prefix(parent.maxLength))
            }
            parent.text = textField.text ?? ""
            textField.font = UIFont.systemFont(ofSize: DynamicFontSizeTextField.dynamicSize(parent.text))
        }
    }
}


extension SwiftUI.Image {
    static var imageCache = NSCache<NSURL, UIImage>()
    
    func data(url: URL) -> Self {
        if let cachedImage = SwiftUI.Image.imageCache.object(forKey: url as NSURL) {
            return SwiftUI.Image(uiImage: cachedImage).resizable()
        }
        
        var downloadedImage: UIImage?
        do {
            let data = try Data(contentsOf: url)
            downloadedImage = UIImage(data: data)
            if let image = downloadedImage {
                SwiftUI.Image.imageCache.setObject(image, forKey: url as NSURL)
                return SwiftUI.Image(uiImage: image).resizable()
            }
        } catch {
            print("Error loading image from URL: \(error)")
        }
        
        return self.resizable()
    }
}


struct LimitLengthModifier: ViewModifier {
    @Binding var text: String
    var length: Int

    func body(content: Content) -> some View {
        content
            .onReceive(text.publisher.collect()) {
                if $0.count > length {
                    text = String($0.prefix(length))
                }
            }
    }
}

extension View {
    func limitLength(_ text: Binding<String>, to length: Int) -> some View {
        self.modifier(LimitLengthModifier(text: text, length: length))
    }
}
