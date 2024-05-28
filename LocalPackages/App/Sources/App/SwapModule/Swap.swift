//
//  SwiftUIView.swift
//  
//
//  Created by davidtam on 23/5/24.
//

import SwiftUI
import Combine
import Kingfisher
import TKUIKit

struct Swap: View {
    @StateObject var vm: SwapVM
    init(vm: SwapVM = SwapVM()) {
        _vm = StateObject(wrappedValue: vm)
    }
    
    private var numberFormatter: NumberFormatter {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 2
        return formatter
    }
    
    @ViewBuilder
    func buildHeader() -> some View {
        HeaderView {
            Text("Swap")
                .font(.title3.bold())
                .foregroundColor(vm.mainLabel)
        } left: {
            NavigationLink {
                SwapSlippage()
                    .environmentObject(vm)
            } label: {
                SwiftUI.Image(uiImage: UIImage.TKUIKit.Icons.Size32.slider)
                    .resizable()
                    .frame(width: 32, height: 32)
                    .clipShape(Circle())
            }
        } right: {
            SwiftUI.Image(uiImage: UIImage.TKUIKit.Icons.Size32.xmark)
                .resizable()
                .frame(width: 32, height: 32)
                .clipShape(Circle())
                .onTapGesture {
                    vm.didTapDismiss?()
                }
        }
        .frame(height: 50)
    }
    
    @ViewBuilder
    func buildTokenIcon(width: CGFloat, urlString: String?) -> some View {
        if let url = URL(string: urlString ?? "") {
            KFImage(url)
                .placeholder({
                    SwiftUI.Image(systemName: "questionmark.circle.fill")
                        .resizable()
                        .frame(width: width, height: width, alignment: .center)
                        .clipShape(Circle())
                })
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: width, height: width, alignment: .center)
                .clipShape(Circle())
        } else {
            SwiftUI.Image(systemName: "questionmark.circle.fill")
                .resizable()
                .frame(width: width, height: width, alignment: .center)
                .clipShape(Circle())
        }
    }
    
    @ViewBuilder
    func buildFromAssetView() -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center) {
                Text("Send")
                    .font(.callout)
                    .foregroundColor(vm.secondaryLabel)
                Spacer()
                
                if let asset = vm.wallet[vm.offerToken] {
                    Text("Balance: \(String(asset.balance)) \(asset.code)")
                        .font(.callout)
                        .foregroundColor(vm.secondaryLabel)
                    Text("MAX")
                        .font(.body.bold())
                        .onTapGesture {
                            vm.mediumFeedback?.impactOccurred()
                            vm.offerAmount = String(asset.balance)
                        }
                }
            }
            
            HStack(alignment: .center) {
                buildTokenButton(token: $vm.offerToken, isOfferAsset: .constant(true))
                Spacer()
                TextField("0", text: $vm.offerAmount)
                    .fixedSize(horizontal: true, vertical: false)
                    .font(.title.bold())
                    .limitLength($vm.offerAmount, to: 9)
                    .keyboardType(.decimalPad)
            }
        }
        .padding(.horizontal)
        .frame(height: 100)
        .background(vm.layer2)
        .clipShape(RoundedRectangle(cornerRadius: vm.cornerRadius, style: .continuous))
    }
    
    @ViewBuilder
    func buildToAssetView() -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center) {
                Text("Receive")
                    .font(.callout)
                    .foregroundColor(vm.secondaryLabel)
                Spacer()
            }
            
            HStack(alignment: .center) {
                buildTokenButton(token: $vm.askToken, isOfferAsset: .constant(false))
                Spacer()
                Text(vm.simutale?.getAskUnits() ?? "0")
                    .font(.title.bold())
                    .foregroundColor(vm.mainLabel)
            }
            
            if let rate = vm.swapRate, !rate.isEmpty {
                Divider()
                HStack(alignment: .center) {
                    Text(rate)
                    Spacer()
                    ProgressView()
                }
                .font(.callout)
                .foregroundColor(vm.secondaryLabel)
                Divider()
            }
            
            vm.simutale?.buildView(mainLabel: vm.mainLabel, secondaryLabel: vm.secondaryLabel,
                                   askToken: vm.askToken, feeToken: vm.offerToken)
        }
        .padding()
        .background(vm.layer2)
        .clipShape(RoundedRectangle(cornerRadius: vm.cornerRadius, style: .continuous))
    }
    
    @ViewBuilder
    func buildSwapIcon() -> some View {
        HStack(alignment: .center) {
            Spacer()
            VStack {
                Spacer()
                    .frame(height: 86)
                
                SwiftUI.Image(systemName: "arrow.up.arrow.down")
                    .resizable()
                    .frame(width: 18, height: 18)
                    .foregroundColor(vm.mainLabel)
                    .padding(10)
                    .background(vm.layer3)
                    .clipShape(Circle())
                    .padding(.trailing, 40)
            }
        }
        .onTapGesture {
            vm.mediumFeedback?.impactOccurred()
            
            // swap
            let temp = vm.askToken
            vm.askToken = vm.offerToken
            vm.offerToken = temp
            
            vm.receiveAmount = 0
        }
    }
    
    @ViewBuilder
    func buildSwapButton() -> some View {
        Group {
            if case .enterAmount = vm.status {
                Text("Enter amount")
            }
            
            if case .chooseToken = vm.status {
                Text("Choose token")
            }
            
            if case .loading = vm.status {
                ProgressView()
            }
        }
        .font(.body.bold())
        .frame(maxWidth: .infinity)
        .frame(height: 50)
        .background(vm.layer2)
        .foregroundColor(vm.mainLabel)
        .clipShape(RoundedRectangle(cornerRadius: vm.cornerRadius, style: .continuous))
    }
    
    @ViewBuilder
    func buildTokenButton(token: Binding<String>, isOfferAsset: Binding<Bool>) -> some View {
        NavigationLink {
            SwapToken(token: token, isOfferAsset: isOfferAsset)
                .environmentObject(vm)
        } label: {
            if token.wrappedValue.isEmpty {
                Text("Choose".uppercased())
                    .font(.body.bold())
                    .foregroundColor(vm.mainLabel)
                    .padding(6)
                    .background(vm.layer3)
                    .clipShape(Capsule())
            } else {
                HStack(alignment: .center, spacing: 4) {
                    buildTokenIcon(
                        width: 24,
                        urlString: vm.swapableAsset.first(where: {
                            $0.symbol?.uppercased() == token.wrappedValue.uppercased()
                        })?.imageURL
                    )
                    Text(token.wrappedValue.uppercased())
                        .font(.body.bold())
                        .foregroundColor(vm.mainLabel)
                }
                .padding(6)
                .background(vm.layer3)
                .clipShape(Capsule())
            }
        }
    }
    
    @ViewBuilder
    func buildNavigationToConfirm() -> some View {
        NavigationLink {
            SwapConfirm()
                .environmentObject(vm)
        } label: {
            Text("Continue")
                .padding()
                .font(.body.bold())
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(vm.layer2)
                .foregroundColor(vm.mainLabel)
                .clipShape(RoundedRectangle(cornerRadius: vm.cornerRadius, style: .continuous))
        }
        .simultaneousGesture(TapGesture().onEnded({ _ in
            vm.shouldCommitChange = false
            vm.mediumFeedback?.impactOccurred()
        }))
    }
    
    var body: some View {
        ZStack {
            vm.layer1.ignoresSafeArea()
            
            VStack(alignment: .leading, spacing: 16) {
                buildHeader()
                
                ScrollView(showsIndicators: false) {
                    ZStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 10) {
                            buildFromAssetView()
                            buildToAssetView()
                        }
                        buildSwapIcon()
                    }
                    
                    Group {
                        if case .ready = vm.status {
                            buildNavigationToConfirm()
                        } else {
                            buildSwapButton()
                        }
                    }
                    .padding(.top, 10)
                }
            }
            .navigationBarBackButtonHidden(true)
            
            .background(vm.layer1)
            .padding()
            
            .contentShape(Rectangle())
            .onTapGesture {
                hideKeyboard()
            }
            
            .onAppear {
                vm.shouldCommitChange = true
                if vm.mediumFeedback == nil {
                    vm.initHaptic()
                }
                
                if vm.methods == nil {
                    vm.update { result in
                        DispatchQueue.main.async {
                            print(result)
                            
                            switch result {
                            case .success(let data):
                                if let method = data.result {
                                    vm.methods = method
                                    vm.swapableAsset = method.assets ?? []
                                }
                                
                            case .failure(let error):
                                print(error.localizedDescription)
                            }
                        }
                    }
                }
            }
        }
    }
}

#Preview {
    Swap()
}


struct Asset {
    var name: String
    var code: String
    var balance: Double
}

enum SwapStatus {
    case enterAmount
    case chooseToken
    case loading
    case ready
    case failure
    case success
}

typealias SwapMethodHandler = (Result<RPCResponse<SwapMethod>, HTTPError>) -> Void
typealias SwapSimulateHandler = (Result<RPCResponse<SwapSimulate>, HTTPError>) -> Void

final
class SwapVM: ObservableObject {
    var didTapDismiss: EmptyHandler?
    
    // api
    @Published var methods: SwapMethod?
    @Published var simutale: SwapSimulate?
    
    @Published var swapableAsset: [SwapAsset] = []
    var suggestedTokens: [String] = [
        "ton",
        "not",
    ]
    
    @Published var status: SwapStatus = .enterAmount
    
    @Published var wallet: [String: Asset] = [
        "TON": Asset(name: "Toncoin", code: "TON", balance: 999),
        "USDT": Asset(name: "Tether USD", code: "USD₮", balance: 333)
    ]
    
    // input
    var shouldCommitChange: Bool = false
    @Published var offerToken: String = ""
    @Published var offerAmount: String = ""
    @Published var askToken: String = ""
    
    // computed
    @Published var receiveAmount: Double = 0
    @Published var swapRate: String?
    
    // searching
    @Published var isSearching: Bool = false // smooth transition
    @Published var searchQuery: String = ""
    @Published var searchResult: [SwapAsset] = []
    
    // setting
    @Published var slippage: Double = 1
    @Published var predefinedSlippage: [Double] = [1,3,5]
    @Published var isExpert = false
    
    var cancellables = Set<AnyCancellable>()
    
    let main: Color // = Color.blue
    let layer1: Color // = Color(UIColor.secondarySystemBackground)
    let layer2: Color // = Color(UIColor.secondarySystemFill)
    let layer3: Color // = Color(UIColor.secondaryLabel)
    let mainLabel: Color // = Color.primary
    let secondaryLabel: Color // = Color.secondary
    
    let cornerRadius: CGFloat = 14
    
    // haptic
    var lightFeedback: UIImpactFeedbackGenerator?
    var mediumFeedback: UIImpactFeedbackGenerator?
    var heavyFeedback: UIImpactFeedbackGenerator?
    var rigidFeedback: UIImpactFeedbackGenerator?
    var softFeedback: UIImpactFeedbackGenerator?
    
    init(didTapDismiss: EmptyHandler? = nil,
         main: Color = Color.blue,
         layer1: Color = Color(UIColor.secondarySystemBackground),
         layer2: Color = Color(UIColor.secondarySystemFill),
         layer3: Color = Color(UIColor.secondaryLabel),
         mainLabel: Color = Color.primary,
         secondaryLabel: Color = Color.secondary
    ) {
        self.main = main
        self.layer1 = layer1
        self.layer2 = layer2
        self.layer3 = layer3
        self.mainLabel = mainLabel
        self.secondaryLabel = secondaryLabel
        
        self.didTapDismiss = didTapDismiss
     
        Publishers.CombineLatest4($offerToken, $offerAmount, $askToken, $slippage)
            .debounce(for: .milliseconds(300), scheduler: RunLoop.main)
            .sink { [weak self] _ in
                self?.updateState()
            }
            .store(in: &cancellables)
        
        $searchQuery
            .debounce(for: .milliseconds(300), scheduler: RunLoop.main)
            .sink { [weak self] _ in
                self?.performSearch()
            }
            .store(in: &cancellables)
    }
    
    func update(completion: SwapMethodHandler? = nil) {
        let jsonString = """
        {
            "jsonrpc": "2.0",
            "id": 1,
            "method": "asset.list",
            "params": {
                "load_community": false
            }
        }
        """

        guard let jsonData = jsonString.data(using: .utf8) else {
            print("Failed to convert JSON string to Data")
            completion?(.failure(.invalidData))
            return
        }
        
        Network(apiFetcher: APIFetcher()).getSwapMethods(body: jsonData) { result in
            completion?(result)
        }
    }
    
    func simulateSwap(
        offerAddress: String, askAddress: String,
        offerUnits: String, slippage: String,
        completion: SwapSimulateHandler? = nil
    ) {
        let jsonString = """
        {
            "jsonrpc": "2.0",
            "id": 4,
            "method": "dex.simulate_swap",
            "params": {
                "offer_address": "\(offerAddress)",
                "offer_units": "\(offerUnits)",
                "ask_address": "\(askAddress)",
                "slippage_tolerance": "\(slippage)",
                "referral_address": "EQBsju9UnwA_T0IdAJrt5Qfj91NWZ7Y56Y_Qm1XI_A4jyzHr"
            }
        }
        """
        
        guard let jsonData = jsonString.data(using: .utf8) else {
            print("Failed to convert JSON string to Data")
            completion?(.failure(.invalidData))
            return
        }
        
        print(jsonString as NSObject)
        
        Network(apiFetcher: APIFetcher()).getSwapSimulate(body: jsonData) { result in
            completion?(result)
        }
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
    
    func updateState() {
        guard shouldCommitChange else { return }
        
        // reset
        self.swapRate = nil
        self.simutale = nil
        
        let dontHaveOfferToken = offerToken.isEmpty
        let dontHaveOfferAmount = offerAmount.isEmpty
        let dontHaveAskToken = askToken.isEmpty
        let dontHaveAskAmount = receiveAmount == 0
        let dontHaveSimulate = simutale == nil
        
        if dontHaveOfferAmount {
            status = .enterAmount
            return
        }
        
        if dontHaveOfferToken || dontHaveAskToken {
            status = .chooseToken
            return
        }
        
        if dontHaveSimulate {
            status = .loading
            
//            // mock loading detail
//            DispatchQueue.main.asyncAfter(deadline: .now() + 1, execute: {
//                self.swapRate = "1 \(self.sendToken) ~= ? \(self.receiveToken)"
//                self.detail = SwapDetail.defaultInstance
//                self.status = .ready
//            })
            
            simulateSwap(
                offerAddress: self.swapableAsset.first(where: { $0.symbol?.uppercased() == self.offerToken.uppercased() })?.contractAddress ?? "",
                askAddress: self.swapableAsset.first(where: { $0.symbol?.uppercased() == self.askToken.uppercased() })?.contractAddress ?? "",
                offerUnits: "\(Int((Double(self.offerAmount) ?? 0) * 1_000_000_000))",
                slippage: "\(slippage)"
            ) { result in
                DispatchQueue.main.async {
                    switch result {
                    case .success(let data):
                        if let simulate = data.result {
                            self.simutale = simulate
                        }
                        
                    case .failure(let error):
                        print(error.localizedDescription)
                    }
                    
                    self.status = .ready
                }
            }
            
            return
        }
        
        if !dontHaveOfferAmount &&
            !dontHaveAskToken &&
            !dontHaveAskAmount &&
            !dontHaveSimulate {
            status = .ready
            return
        }
    }
    
    func performSearch() {
        withAnimation {
            self.isSearching = !self.searchQuery.isEmpty
        }
        
        self.searchResult = self.swapableAsset.filter({ item in
            (item.symbol?.lowercased() ?? "").contains(self.searchQuery.lowercased()) ||
            (item.displayName?.lowercased() ?? "").contains(self.searchQuery.lowercased())
        })
    }
}
