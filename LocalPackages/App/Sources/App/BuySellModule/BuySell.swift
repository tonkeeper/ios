import SwiftUI
import UIKit
import TKLocalize
import TKUIKit

extension String {
    func process() -> String {
        guard let systemSeparator = Locale.current.decimalSeparator else {
            return "0"
        }
        
        var chunks: [String] = self.components(separatedBy: systemSeparator)
        
        let integralPart: String = chunks.first ?? "0"
        chunks.removeFirst()
        let fractionalPart: String = chunks.joined(separator: "")
        
        if fractionalPart.isEmpty {
            return integralPart
        } else {
            let result = "\(integralPart)\(systemSeparator)\(fractionalPart)"
            return result
        }
    }
}

extension Double {
    var trimmedString: String {
        let formatter = NumberFormatter()
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 9
        return formatter.string(for: self) ?? ""
    }
    
    func trimmed(precision: Int = 9) -> String {
        let formatter = NumberFormatter()
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = precision
        return formatter.string(for: self) ?? ""
    }
}

enum PayMethod: String, CaseIterable {
    case creditCardVisaMaster = "creditcard.global"
    case creditCardRUB = "creditcard.rub"
    case crypto = "crypto"
    case applePay = "applepay"
    
    func getImage() -> UIImage {
        switch self {
        case .creditCardVisaMaster: return .TKUIKit.Icons.Size56.creditcardGlobal
        case .creditCardRUB: return .TKUIKit.Icons.Size56.creditcardRub
        case .crypto: return .TKUIKit.Icons.Size56.cryptocurrency
        case .applePay: return .TKUIKit.Icons.Size56.applepay
        }
    }
    
    func getName() -> String {
        switch self {
        case .creditCardVisaMaster: return TKLocales.Buysell.Method.Creditcard.global
        case .creditCardRUB: return TKLocales.Buysell.Method.Creditcard.rub
        case .crypto: return TKLocales.Buysell.Method.crypto
        case .applePay: return TKLocales.Buysell.Method.applepay
        }
    }
}

typealias EmptyHandler = () -> Void
typealias FiatMethodHandler = (Result<FiatMethodResponse, HTTPError>) -> Void

//struct BuySellView: View {
//    @StateObject var vm: BuySellVM
//    
//    @State private var temp = "0"
//    @State var showCountry = false
//    
//    init(vm: BuySellVM = BuySellVM()) {
//        _vm = StateObject(wrappedValue: vm)
//    }
//    
//    @ViewBuilder
//    func textField() -> some View {
//        HStack(alignment: .center, spacing: 4) {
//            DynamicFontSizeTextField(text: $temp, maxLength: 15)
//                .fixedSize(horizontal: true, vertical: false)
//                .keyboardType(.decimalPad)
//                .foregroundColor(Color.white)
//                .multilineTextAlignment(.center)
//
//            Button {} label: {
//                Text(vm.asset)
//                    .font(.system(size: DynamicFontSizeTextField.dynamicSize(temp), weight: .bold, design: .default))
//            }
//            .foregroundColor(Color.gray.opacity(0.8))
//            
////            Picker("Token?", selection: $vm.asset) {
////                ForEach(vm.assets, id: \.self) { key in
////                    Text(key).tag(key)
////                }
////            }
////            .pickerStyle(.menu)
////            .border(.red, width: 1)
//        }
//    }
//    
//    var body: some View {
//        VStack {
//            HeaderView {
//                HStack(alignment: .center, spacing: 0) {
//                    Button {
//                        vm.isBuy = true
//                        vm.updateMerchants()
//                    } label: {
//                        VStack(alignment: .center, spacing: 4) {
//                            Text("Buy")
//                                .font(.headline.bold())
//                            
//                            if vm.isBuy {
//                                Color.blue
//                                    .frame(height: 3)
//                                    .frame(maxWidth: .infinity)
//                            } else {
//                                Color.clear
//                                    .frame(height: 3)
//                                    .frame(maxWidth: .infinity)
//                            }
//                        }
//                        .frame(width: 50)
//                    }
//                    .foregroundColor(vm.isBuy ? .primary : .secondary)
//                    
//                    Button {
//                        vm.isBuy = false
//                        // vm.updateMerchants()
//                    } label: {
//                        VStack(alignment: .center, spacing: 4) {
//                            Text("Sell")
//                                .font(.headline.bold())
//                            
//                            if !vm.isBuy {
//                                Color.blue
//                                    .frame(height: 3)
//                                    .frame(maxWidth: .infinity)
//                            } else {
//                                Color.clear
//                                    .frame(height: 3)
//                                    .frame(maxWidth: .infinity)
//                            }
//                        }
//                        .frame(width: 50)
//                    }
//                    .foregroundColor(!vm.isBuy ? .primary : .secondary)
//                }
//            } left: {
//                Button {
//                    showCountry = true
//                } label: {
//                    Text(vm.country)
//                        .font(.callout.bold())
//                }
//                .padding(.vertical, 6)
//                .padding(.horizontal, 8)
//                .foregroundColor(Color.primary)
//                .background(Color(UIColor.Button.secondaryBackground))
//                .clipShape(Capsule())
//            } right: {
//                Button {
//                    vm.onDismiss?()
//                } label: {
//                    SwiftUI.Image(uiImage: .TKUIKit.Icons.Size32.xmark)
//                }
//            }
//            .frame(height: 50)
//            
//            if vm.resp.data == nil {
//                Spacer()
//                Text("Loading ..")
//            } else {
//                VStack(alignment: .center, spacing: 14) {
//                    textField()
//                    VStack(alignment: .center, spacing: 12) {
//                        Text("6000.01 USD")
//                            .padding(8)
//                            .font(.caption)
//                            .foregroundColor(Color(UIColor.secondaryLabel))
//                            .overlay(
//                                Capsule()
//                                    .stroke(Color.secondary, lineWidth: 1)
//                            )
//                        
//                        Text("Min. amount: 50 TON")
//                            .font(.system(size: 14, weight: .light, design: .rounded))
//                            .foregroundColor(Color(UIColor.secondaryLabel))
//                    }
//                }
//                .padding(.vertical, 16)
//                .frame(maxWidth: .infinity)
//                .background(Color(UIColor.Background.content))
//                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
//                .frame(height: 160)
//                
//                ScrollView {
//                    VStack(spacing: 0) {
//                        ForEach(PayMethod.allCases, id: \.rawValue) { method in
//                            Button {
//                                vm.method = method.rawValue
//                            } label: {
//                                HStack {
//                                    if vm.method == method.rawValue {
//                                        SwiftUI.Image(uiImage: .TKUIKit.Icons.Size28.radioSelected)
//                                            .foregroundColor(Color(UIColor.Button.primaryBackground))
//                                    } else {
//                                        SwiftUI.Image(uiImage: .TKUIKit.Icons.Size28.radioUnselect)
//                                            .foregroundColor(Color(UIColor.Button.tertiaryBackground))
//                                    }
//                                    
//                                    Text(method.getName())
//                                        .multilineTextAlignment(.leading)
//                                        .padding(.leading, 6)
//                                        .foregroundColor(Color.primary)
//                                    
//                                    Spacer()
//                                    
//                                    SwiftUI.Image(uiImage: method.getImage())
//                                }
//                            }
//                            .frame(height: 56)
//                            .padding(.leading, 10)
//                            .font(.system(size: 16, weight: .medium, design: .rounded))
//                        }
//                    }
//                    .background(Color(UIColor.Background.content))
//                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
//                }
//            }
//            
//            Spacer()
//            
//            if vm.resp.data != nil {
//                NavigationLink {
//                    BuySellMerchant()
//                        .environmentObject(vm)
//                } label: {
//                    Text("Continue")
//                }
//                .buttonStyle(BigButtonStyle(backgroundColor: Color(UIColor.Button.primaryBackground), textColor: .white))
//            }
//        }
//        .onAppear {
//            if vm.resp.data == nil {
//                vm.update()
//            }
//        }
//        .padding()
//        .navigationBarBackButtonHidden(true)
//        
//        .background(Color(UIColor.Background.page))
//        
//        .sheet(isPresented: $showCountry) {
//            BuySellCurrency()
//                .environmentObject(vm)
//        }
//        
//        .contentShape(Rectangle())
//        .onTapGesture {
//            hideKeyboard()
//        }
//    }
//}

struct BuySell: View {
    @StateObject var vm: BuySellVM
    init(vm: BuySellVM = BuySellVM()) {
        _vm = StateObject(wrappedValue: vm)
    }
    
    @State var showCountry = false
    
    @ViewBuilder
    func textField() -> some View {
        HStack(alignment: .center, spacing: 4) {
            DynamicSizeInputField(text: $vm.amount, maxLength: vm.maxInputLength)
                .fixedSize(horizontal: true, vertical: false)
                .keyboardType(.decimalPad)
                .foregroundColor(vm.mainLabel)
                .multilineTextAlignment(.center)

            Button {} label: {
                Text(vm.asset)
                    .font(.system(size: DynamicFontSizeTextField.dynamicSize(vm.amount), weight: .bold, design: .default))
            }
            .foregroundColor(vm.secondaryLabel)
            
//            Picker("Token?", selection: $vm.asset) {
//                ForEach(vm.assets, id: \.self) { key in
//                    Text(key).tag(key)
//                }
//            }
//            .pickerStyle(.menu)
//            .border(.red, width: 1)
        }
    }
    
    @ViewBuilder
    func buildBuySellHeader() -> some View {
        HStack(alignment: .center, spacing: 8) {
            Button {
                vm.mediumFeedback?.impactOccurred()
                vm.isBuy = true
                vm.updateMerchants()
            } label: {
                VStack(alignment: .center, spacing: 4) {
                    Text("Buy")
                        .font(.title3.bold())
                    
                    if vm.isBuy {
                        Color.blue
                            .frame(height: 3)
                            .frame(maxWidth: .infinity)
                    } else {
                        Color.clear
                            .frame(height: 3)
                            .frame(maxWidth: .infinity)
                    }
                }
                .frame(width: 50)
            }
            .foregroundColor(vm.isBuy ? .primary : .secondary)
            
            Button {
                vm.mediumFeedback?.impactOccurred()
                vm.isBuy = false
                // vm.updateMerchants()
            } label: {
                VStack(alignment: .center, spacing: 4) {
                    Text("Sell")
                        .font(.title3.bold())
                    
                    if !vm.isBuy {
                        Color.blue
                            .frame(height: 3)
                            .frame(maxWidth: .infinity)
                    } else {
                        Color.clear
                            .frame(height: 3)
                            .frame(maxWidth: .infinity)
                    }
                }
                .frame(width: 56)
            }
            .foregroundColor(!vm.isBuy ? .primary : .secondary)
        }
    }
    
    @ViewBuilder
    func buildHeader() -> some View {
        HeaderView {
            buildBuySellHeader()
        } left: {
            Text(vm.country)
                .font(.caption.bold())
                .padding(8)
                .background(vm.layer2)
                .clipShape(Capsule())
                .onTapGesture {
                    vm.mediumFeedback?.impactOccurred()
                    showCountry = true
                }
        } right: {
            SwiftUI.Image(uiImage: .TKUIKit.Icons.Size32.xmark)
                .frame(width: 32, height: 32)
                .clipShape(Circle())
                .onTapGesture {
                    vm.mediumFeedback?.impactOccurred()
                    vm.didTapDismiss?()
                }
        }
        .frame(height: 50)
    }
    
    @ViewBuilder
    func buildLoading() -> some View {
        VStack {
            Spacer()
            Text("Loading ..")
                .frame(maxWidth: .infinity, alignment: .center)
            Spacer()
        }
    }
    
    @ViewBuilder
    func buildBuySellValue() -> some View {
        Group {
            if let buysellAmount = Double(vm.amount.prefix(vm.maxInputLength)) {
                Text("\((buysellAmount*vm.rate).trimmedString) \(vm.currency.uppercased())")
            } else {
                Text("0 \(vm.currency.uppercased())")
            }
        }
        .padding(8)
        .font(.caption)
        .foregroundColor(vm.secondaryLabel)
        .overlay(
            Capsule()
                .stroke(vm.secondaryLabel, lineWidth: 1)
        )
    }
    
    @ViewBuilder
    func buildAmountInput() -> some View {
        VStack(alignment: .center, spacing: 16) {
            textField()
                .padding(.top, 12)
            
            VStack(alignment: .center, spacing: 12) {
                buildBuySellValue()
                
                Text("Min. amount: \(vm.minAmount.trimmedString) \(vm.asset)")
                    .font(.caption)
                    .foregroundColor(vm.secondaryLabel)
            }
        }
        .padding(.vertical, 20)
        .frame(maxWidth: .infinity)
        .background(vm.layer2)
        .clipShape(RoundedRectangle(cornerRadius: vm.cornerRadius, style: .continuous))
    }
    
    @ViewBuilder
    func buildPaymentOptions() -> some View {
        VStack(spacing: 0) {
            ForEach(PayMethod.allCases, id: \.rawValue) { method in
                Button {
                    vm.mediumFeedback?.impactOccurred()
                    vm.method = method.rawValue
                } label: {
                    HStack {
                        if vm.method == method.rawValue {
                            SwiftUI.Image(uiImage: .TKUIKit.Icons.Size28.radioSelected)
                                .foregroundColor(Color(UIColor.Button.primaryBackground))
                        } else {
                            SwiftUI.Image(uiImage: .TKUIKit.Icons.Size28.radioUnselect)
                                .foregroundColor(Color(UIColor.Button.tertiaryBackground))
                        }
                        
                        Text(method.getName())
                            .multilineTextAlignment(.leading)
                            .padding(.leading, 6)
                            .foregroundColor(Color.primary)
                        
                        Spacer()
                        
                        SwiftUI.Image(uiImage: method.getImage())
                    }
                }
                .frame(height: 56)
                .padding(.leading, 10)
                .font(.system(size: 16, weight: .medium, design: .rounded))
            }
        }
        .background(vm.layer2)
        .clipShape(RoundedRectangle(cornerRadius: vm.cornerRadius, style: .continuous))
    }
    
    @ViewBuilder
    func buildContinueButton() -> some View {
        if let buySellAmount = Double(vm.amount),
           buySellAmount > 0 && vm.resp.data != nil && buySellAmount >= vm.minAmount {
            NavigationLink {
                BuySellMerchant()
                    .environmentObject(vm)
            } label: {
                Text("Continue")
                    .font(.headline.bold())
                    .frame(maxWidth: .infinity)
                    .padding()
                    .foregroundColor(vm.mainLabel)
                    .background(vm.main)
                    .clipShape(RoundedRectangle(cornerRadius: vm.cornerRadius, style: .continuous))
            }
            .gesture(TapGesture().onEnded({ _ in
                vm.mediumFeedback?.impactOccurred()
            }))
        } else {
            Text("Continue")
                .font(.headline.bold())
                .frame(maxWidth: .infinity)
                .padding()
                .foregroundColor(vm.secondaryLabel)
                .background(vm.main.opacity(0.7))
                .clipShape(RoundedRectangle(cornerRadius: vm.cornerRadius, style: .continuous))
        }
    }
    
    var body: some View {
        ZStack {
            vm.layer1.ignoresSafeArea()
            
            VStack(alignment: .leading, spacing: 16) {
                if vm.resp.data == nil {
                    buildLoading()
                } else {
                    buildHeader()
                    ScrollView {
                        buildAmountInput()
                        buildPaymentOptions()
                    }
                    
                    Spacer()
                    buildContinueButton()
                }
            }
            
            .onAppear {
                if vm.resp.data == nil {
                    vm.update()
                }
                
                if vm.mediumFeedback == nil {
                    vm.initHaptic()
                }
            }
            
            .padding()
            .navigationBarBackButtonHidden(true)
            
            .sheet(isPresented: $showCountry) {
                BuySellCurrency()
                    .environmentObject(vm)
            }
            
            .contentShape(Rectangle())
            .onTapGesture {
                hideKeyboard()
            }
        }
    }
}

#Preview {
    BuySell()
}

extension BuySellVM {
    static let countriesInfo: [String: String] = [
        "RU": "Russia Ruble",
        "UA": "Ukraine Hryvnia",
        "DE": "Germany Euro",
        "ID": "Indonesia Rupiah",
        "IN": "India Rupee",
        "US": "United States Dollar",
        "BY": "Belarus Ruble",
        "GB": "United Kingdom Pound",
        "FR": "France Euro",
        "BR": "Brazil Real",
        "NG": "Nigeria Naira",
        "CA": "Canada Dollar",
    ]
}

final
class BuySellVM: ObservableObject {
    var didTapDismiss: EmptyHandler?
    
    // computed from api
    @Published var resp: FiatMethodResponse = .init(success: nil, data: nil)
    @Published var error: String = ""
    @Published var countries: [CountryLayout] = []
    @Published var assets: [String] = []
    @Published var merchants: [Merchant] = []
    @Published var minAmount: Double = 50
    
    let maxInputLength: Int = 13
    
    // default params
    @Published var isBuy: Bool = true
    @Published var amount: String = "0"
    @Published var asset: String = "TON"
    @Published var rate: Double = 6.1
    @Published var currency: String = "USD"
    @Published var country: String = "US"
    @Published var method: String = PayMethod.creditCardVisaMaster.rawValue
    @Published var merchant: String = "" // service provider
    
    // theme
    let main: Color // = Color.blue
    let layer1: Color // = Color(UIColor.secondarySystemBackground)
    let layer2: Color // = Color(UIColor.secondarySystemFill)
    let layer3: Color // = Color(UIColor.secondaryLabel)
    let mainLabel: Color // = Color.primary
    let secondaryLabel: Color // = Color.secondary
    
    let tagTint: Color = Color.blue
    let tagBackground: Color = Color.blue.opacity(0.3)
    let cornerRadius: CGFloat = 10
    
    // haptic
    var lightFeedback: UIImpactFeedbackGenerator?
    var mediumFeedback: UIImpactFeedbackGenerator?
    var heavyFeedback: UIImpactFeedbackGenerator?
    var rigidFeedback: UIImpactFeedbackGenerator?
    var softFeedback: UIImpactFeedbackGenerator?
    
    init(onDismiss: EmptyHandler? = nil,
         main: Color = Color.blue,
         layer1: Color = Color(UIColor.secondarySystemBackground),
         layer2: Color = Color(UIColor.secondarySystemFill),
         layer3: Color = Color(UIColor.secondaryLabel),
         mainLabel: Color = Color.primary,
         secondaryLabel: Color = Color.secondary
    ) {
        self.didTapDismiss = onDismiss
        
        self.main = main
        self.layer1 = layer1
        self.layer2 = layer2
        self.layer3 = layer3
        self.mainLabel = mainLabel
        self.secondaryLabel = secondaryLabel
    }
    
    func initHaptic() {
        lightFeedback = UIImpactFeedbackGenerator(style: .light)
        lightFeedback?.prepare()
        
        mediumFeedback = UIImpactFeedbackGenerator(style: .medium)
        mediumFeedback?.prepare()
        
        heavyFeedback = UIImpactFeedbackGenerator(style: .heavy)
        heavyFeedback?.prepare()
        
        rigidFeedback = UIImpactFeedbackGenerator(style: .rigid)
        rigidFeedback?.prepare()
        
        softFeedback = UIImpactFeedbackGenerator(style: .soft)
        softFeedback?.prepare()
    }
    
    func update(completion: FiatMethodHandler? = nil) {
        DispatchQueue.main.async {
            Network(apiFetcher: APIFetcher()).getFiatMethods { result in
                switch result {
                case .success(let data):
                    withAnimation {
                        self.resp = data
                    }
                    
                    // TODO: update default params
                    if let countries = data.data?.layoutByCountry {
                        self.countries = countries
                        self.country = self.countries.first?.countryCode ?? "?"
                    }
                    
                    self.updateMerchants()
                    
                case .failure(let error):
                    self.error = error.localizedDescription
                }
                
                completion?(result)
            }
        }
    }
    
    func updateMerchants() {
        guard self.resp.data != nil else { return }
        
        // reset
        self.assets = []
        self.merchants = []
        
        switch isBuy {
        case true:
            
            // update asset,each have N merchant available (for 1 mode, not include swap)
            self.resp.data?.buy?.forEach({ buyItem in
                if let assets = buyItem.assets, buyItem.type?.contains("buy") ?? false {
                    // update assets
                    self.assets.append(contentsOf: assets)
                    
                    // update merchants
                    self.merchants.append(contentsOf: buyItem.items ?? [])
                }
            })
            
        case false:
            
            // update asset,each have N merchant available (for 1 mode, not include swap)
            self.resp.data?.sell?.forEach({ sellItem in
                if let assets = sellItem.assets, sellItem.type?.contains("sell") ?? false {
                    // update assets
                    self.assets.append(contentsOf: assets)
                    
                    // update merchants
                    self.merchants.append(contentsOf: sellItem.items ?? [])
                }
            })
        }
    }
}

struct DynamicSizeInputField: UIViewRepresentable {
    @Binding var text: String
    var maxLength: Int

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeUIView(context: Context) -> UITextField {
        let textField = UITextField()
        textField.delegate = context.coordinator
        textField.text = text
        textField.font = UIFont.systemFont(ofSize: DynamicSizeInputField.dynamicSize(text), weight: .bold)
        textField.textColor = UIColor.label
        textField.textAlignment = .center
        textField.keyboardType = .decimalPad
        textField.addTarget(context.coordinator, action: #selector(Coordinator.textFieldDidChange(_:)), for: .editingChanged)
        return textField
    }

    func updateUIView(_ uiView: UITextField, context: Context) {
        if text.isEmpty {
            text = "0"
        }
        
        uiView.text = String(text.prefix(maxLength))
        uiView.font = UIFont.systemFont(ofSize: DynamicSizeInputField.dynamicSize(text))
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
        var parent: DynamicSizeInputField

        init(parent: DynamicSizeInputField) {
            self.parent = parent
        }

        @objc func textFieldDidChange(_ textField: UITextField) {
            let newText = textField.text ?? ""
            if newText.count > parent.maxLength {
                textField.text = String(newText.prefix(parent.maxLength))
            }
            parent.text = (Double(newText.process()) ?? 0).trimmedString
            textField.font = UIFont.systemFont(ofSize: DynamicSizeInputField.dynamicSize(parent.text))
        }
    }
}
