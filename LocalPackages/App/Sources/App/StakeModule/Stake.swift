//
//  SwiftUIView.swift
//  
//
//  Created by davidtam on 24/5/24.
//

import SwiftUI
import TKUIKit

struct Stake: View {
    @StateObject var vm: StakeViewModel
    init(vm: StakeViewModel = StakeViewModel()) {
        _vm = StateObject(wrappedValue: vm)
    }
    
    @State var availableAmount: Double = 0
    
    @ViewBuilder
    func buildHeader() -> some View {
        HeaderView {
            Text("Stake")
                .font(.title3.bold())
        } left: {
            SwiftUI.Image(uiImage: UIImage.TKUIKit.Icons.Size32.info)
                .resizable()
                .frame(width: 32, height: 32)
                .clipShape(Circle())
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
    func buildAvailableAsset() -> some View {
        if let stakeAmount = Double(vm.stakeAmount), vm.maxAmount - stakeAmount >= 0 {
            let available = (vm.maxAmount - stakeAmount).trimmedString
            Text("Available \(available) \(vm.stakeAsset)")
                .font(.body)
                .foregroundColor(vm.secondaryLabel)
        } else {
            Text("Insufficient balance")
                .font(.body)
                .foregroundColor(vm.alertLabel)
        }
    }
    
    @ViewBuilder
    func buildStakeValue() -> some View {
        Group {
            if let stakeAmount = Double(vm.stakeAmount.prefix(vm.maxInputLength)) {
                Text("\((stakeAmount*vm.rate).trimmedString) \(vm.currency.uppercased())")
            } else {
                Text("0 \(vm.currency.uppercased())")
            }
        }
        .padding(8)
        .font(.body)
        .foregroundColor(vm.secondaryLabel)
        .overlay(
            Capsule()
                .stroke(Color.secondary, lineWidth: 1)
        )
    }
    
    @ViewBuilder
    func buildInput() -> some View {
        VStack(alignment: .leading, spacing: 16) {
            
            VStack(alignment: .center, spacing: 6) {
                textField()
                    .frame(height: 50)
                
                buildStakeValue()
            }
            .frame(height: 188)
            .padding()
            .frame(maxWidth: .infinity)
            .background(vm.layer2)
            .clipShape(RoundedRectangle(cornerRadius: vm.cornerRadius, style: .continuous))
            
            HStack {
                Text("MAX")
                    .font(.footnote.bold())
                    .padding(10)
                    .background(vm.maxAmount == (Double(vm.stakeAmount) ?? 0) ? vm.main : vm.layer2)
                    .clipShape(Capsule())
                    .onTapGesture {
                        vm.mediumFeedback?.impactOccurred()
                        vm.stakeAmount = vm.maxAmount.description
                    }
                
                Spacer()
                buildAvailableAsset()
            }
        }
        .padding(.bottom, 16)
    }
    
    @ViewBuilder
    func textField() -> some View {
        HStack(alignment: .center, spacing: 4) {
            DynamicSizeInputField(text: $vm.stakeAmount, maxLength: vm.maxInputLength)
                .fixedSize(horizontal: true, vertical: false)
                .keyboardType(.decimalPad)
                .foregroundColor(Color.white)
                .multilineTextAlignment(.center)

            Button {} label: {
                Text(vm.stakeAsset)
                    .font(.system(size: DynamicSizeInputField.dynamicSize(vm.stakeAmount.description), weight: .bold, design: .default))
            }
            .foregroundColor(Color.gray.opacity(0.8))
            
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
    func buildStakeOption() -> some View {
        NavigationLink {
            StakeOption()
                .environmentObject(vm)
        } label: {
            HStack(alignment: .center, spacing: 16) {
                if let image = vm.selectedStaking.lowercased().getImage() {
                    SwiftUI.Image(uiImage: image)
                        .frame(width: 44, height: 44)
                        .clipShape(Circle())
                } else {
                    vm.layer2
                        .frame(width: 44, height: 44)
                        .clipShape(Circle())
                }
                
                VStack(alignment: .leading, spacing: 6) {
                    HStack(alignment: .center, spacing: 8) {
                        Text("Tonstaker")
                            .font(.headline.bold())
                            .foregroundColor(vm.mainLabel)
                        
                        Text("MAX APY")
                            .font(.system(size: 8, weight: .bold, design: .rounded))
                            .padding(4)
                            .foregroundColor(Color.green)
                            .background(Color.green.opacity(0.3))
                            .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
                    }
                    
                    HStack(alignment: .center, spacing: 4) {
                        Text("APY ~ 5%")
                        Text("-")
                        Text("? TON")
                    }
                    .font(.caption)
                    .foregroundColor(vm.secondaryLabel)
                }
                
                Spacer()
                
                SwiftUI.Image(systemName: "chevron.up.chevron.down")
                    .foregroundColor(vm.secondaryLabel)
            }
            .padding(14)
            .background(vm.layer2)
            .clipShape(RoundedRectangle(cornerRadius: vm.cornerRadius, style: .continuous))
        }
    }
    
    @ViewBuilder
    func buildContinueButton() -> some View {
        if let stakeAmount = Double(vm.stakeAmount), stakeAmount > 0 && vm.maxAmount - stakeAmount >= 0 {
            NavigationLink {
                StakeConfirm()
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
                buildHeader()
                buildInput()
                buildStakeOption()
                
                Spacer()
            }
            
            .onAppear {
                availableAmount = vm.maxAmount
                
                if vm.mediumFeedback == nil {
                    vm.initHaptic()
                }
            }
            
            .navigationBarBackButtonHidden(true)
            .padding()
            
            .contentShape(Rectangle())
            .onTapGesture {
                hideKeyboard()
            }
            
            VStack {
                Spacer()
                buildContinueButton()
            }
            .padding()
        }
    }
}

#Preview {
    Stake()
}

final
class StakeViewModel: ObservableObject {
    var didTapDismiss: EmptyHandler?
    let maxAmount: Double = 3.14159
    
    @Published var stakeAmount: String = "0" // more convenience than double when process floating input
    @Published var stakeAsset: String = "TON"
    @Published var rate: Double = 6.1
    @Published var currency: String = "USD"
    
    let maxInputLength: Int = 13
    
    @Published var stakingDetail: [String: String] = [
        "Wallet": "😳 Main",
        "Recipient": "Provider ?",
        "APY": "~? %",
        "Fee": "~? TON"
    ]
    
    @Published var selectedStaking: String = "tonstakers"
    @Published var liquidStakingOptions: [String] = [
        "tonstakers",
        "bemo",
        "whalesliquid"
    ]
    
    @Published var otherStakingOptions: [String] = [
        "tonwhales",
        "nominators"
    ]
    
    @Published var childStakingOptions: [String] = [
        "tonkeeperqueue#1",
        "tonkeeperqueue#2"
    ]
    
    // theme
    let main: Color // = Color.blue
    let layer1: Color // = Color(UIColor.secondarySystemBackground)
    let layer2: Color // = Color(UIColor.secondarySystemFill)
    let layer3: Color // = Color(UIColor.secondaryLabel)
    let mainLabel: Color // = Color.primary
    let secondaryLabel: Color // = Color.secondary
    let alertLabel: Color // = Color.red
    let cornerRadius: CGFloat = 10
    
    // haptic
    var lightFeedback: UIImpactFeedbackGenerator?
    var mediumFeedback: UIImpactFeedbackGenerator?
    var heavyFeedback: UIImpactFeedbackGenerator?
    var rigidFeedback: UIImpactFeedbackGenerator?
    var softFeedback: UIImpactFeedbackGenerator?
    
    init(
        didTapDismiss: EmptyHandler? = nil,
        main: Color = Color.blue,
        layer1: Color = Color(UIColor.secondarySystemBackground),
        layer2: Color = Color(UIColor.secondarySystemFill),
        layer3: Color = Color(UIColor.secondaryLabel),
        mainLabel: Color = Color.primary,
        secondaryLabel: Color = Color.secondary,
        alertLabel: Color = Color.red
    ) {
        self.didTapDismiss = didTapDismiss
        
        self.main = main
        self.layer1 = layer1
        self.layer2 = layer2
        self.layer3 = layer3
        self.mainLabel = mainLabel
        self.secondaryLabel = secondaryLabel
        self.alertLabel = alertLabel
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
}
