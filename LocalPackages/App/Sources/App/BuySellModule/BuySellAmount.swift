//
//  SwiftUIView.swift
//  
//
//  Created by davidtam on 21/5/24.
//

import SwiftUI
import TKUIKit

struct BuySellAmount: View {
    @Environment(\.presentationMode) var presentation
    @EnvironmentObject var vm: BuySellVM
    
    @State var isFocus: Bool = false
    @State var getAmount: Double = 0
    @State var status: TransactionStatus = .initialize
    
    @ViewBuilder
    func buildHeader() -> some View {
        HeaderView {
            EmptyView()
        } left: {
            SwiftUI.Image(uiImage: .TKUIKit.Icons.Size32.chevronLeft)
                .frame(width: 32, height: 32)
                .clipShape(Circle())
                .onTapGesture {
                    vm.mediumFeedback?.impactOccurred()
                    presentation.wrappedValue.dismiss()
                }
        } right: {
            SwiftUI.Image(uiImage: .TKUIKit.Icons.Size32.xmark)
                .frame(width: 32, height: 32)
                .clipShape(Circle())
                .onTapGesture {
                    vm.didTapDismiss?()
                }
        }
        .frame(height: 50)
    }
    
    @ViewBuilder
    func buildMerchantPreview() -> some View {
        if let merchant = vm.merchants.first(where: { $0.title?.uppercased() == vm.merchant.uppercased() }) {
            VStack(alignment: .center, spacing: 16) {
                SwiftUI.Image(systemName: "")
                    .data(url: URL(string: merchant.iconURL!)!)
                    .frame(width: 72, height: 72)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                
                Text(merchant.title?.capitalized ?? "-")
                    .font(.title2.bold())
                    .foregroundColor(vm.mainLabel)
                
                Text(merchant.subtitle?.capitalized ?? "-")
                    .font(.body)
                    .foregroundColor(vm.secondaryLabel)
            }
            .frame(maxWidth: .infinity)
        } else {
            VStack(alignment: .center, spacing: 16) {
                SwiftUI.Image(systemName: "questionmark.square.fill")
                    .resizable()
                    .frame(width: 72, height: 72)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                
                Text("Please select a merchant")
                    .font(.body.bold())
                    .foregroundColor(vm.mainLabel)
            }
            .frame(maxWidth: .infinity)
        }
    }
    
    @ViewBuilder
    func buildBuySellPreview() -> some View {
        VStack(alignment: .leading, spacing: 16) {
//            if let currency = vm.countries.first(where: { $0.countryCode?.uppercased() == vm.country.uppercased() })?.currency?.uppercased() {
//                VStack(alignment: .leading, spacing: 6) {
//                    Text("You pay" )
//                        .frame(maxWidth: .infinity, alignment: .leading)
//                        .foregroundColor(Color(UIColor.secondaryLabel))
//
//                    textField(isFocus: $isFocus, asset: currency)
//                }
//                .frame(maxWidth: .infinity)
//                .padding()
//                .background(
//                    RoundedRectangle(cornerRadius: 10, style: .continuous)
//                        .fill(Color(UIColor.secondarySystemBackground))
//                )
//                .overlay(
//                    RoundedRectangle(cornerRadius: 10, style: .continuous)
//                        .stroke(isFocus ? Color.blue : Color.clear, lineWidth: 2)
//                )
//            }
            
            VStack(alignment: .leading, spacing: 6) {
                Text("You pay")
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .foregroundColor(vm.secondaryLabel)
                
                textField(isFocus: $isFocus, asset: vm.currency)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(
                RoundedRectangle(cornerRadius: vm.cornerRadius, style: .continuous)
                    .fill(vm.layer2)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(isFocus ? Color.blue : Color.clear, lineWidth: 2)
            )
            
            VStack(alignment: .leading, spacing: 6) {
                Text("You get")
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .foregroundColor(vm.secondaryLabel)
                
                HStack(alignment: .center, spacing: 4) {
                    Text("0.000")
                        .foregroundColor(vm.mainLabel)
                    Text("TON")
                        .foregroundColor(vm.secondaryLabel)
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: vm.cornerRadius, style: .continuous)
                    .fill(vm.layer2)
            )
            
            Text("2,3301.01 AMD for 1 TON")
                .padding(.leading, 12)
                .foregroundColor(vm.secondaryLabel)
        }
    }
    
    @ViewBuilder
    func buildStatusButton() -> some View {
        if case .initialize = status {
            Text("Continue")
                .font(.body.bold())
                .padding()
                .frame(maxWidth: .infinity, alignment: .center)
                .onTapGesture {
                    vm.mediumFeedback?.impactOccurred()
                    status = .processing
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2, execute: {
                        status = [.success, .failed].randomElement()!
                    })
                }
                .background(vm.main)
                .clipShape(RoundedRectangle(cornerRadius: vm.cornerRadius, style: .continuous))
        } else {
            status.getView()
                .background(status.getColor())
                .clipShape(RoundedRectangle(cornerRadius: vm.cornerRadius, style: .continuous))
        }
    }
    
    var body: some View {
        ZStack {
            vm.layer1.ignoresSafeArea()
            
            VStack(alignment: .leading, spacing: 16) {
                buildHeader()
                buildMerchantPreview()
                buildBuySellPreview()
                
                Spacer()
            }
            .padding([.top, .horizontal])
            .navigationBarBackButtonHidden(true)
            
            .contentShape(Rectangle())
            .onTapGesture {
                hideKeyboard()
            }
            
            VStack {
                Spacer()
                buildStatusButton()
            }
            .padding()
        }
    }
    
    @ViewBuilder
    func textField(isFocus: Binding<Bool>, asset: String) -> some View {
        HStack(alignment: .center, spacing: 4) {
            TextField("", text: $vm.amount, onEditingChanged: { edit in
                isFocus.wrappedValue = edit
            })
            .foregroundColor(vm.mainLabel)
            .keyboardType(.decimalPad)
            .fixedSize(horizontal: true, vertical: false)
            .multilineTextAlignment(.center)
            
            Text(asset.uppercased())
                .foregroundColor(vm.secondaryLabel)
        }
    }
}

#Preview {
    BuySellAmount()
}

enum TransactionStatus: Int, CaseIterable {
    case initialize = 0
    case processing
    case success
    case failed
    
    func getName() -> String {
        switch self {
        case .initialize: return "buysell.status.continue"
        case .processing: return "buysell.status.processing"
        case .success: return "buysell.status.success"
        case .failed: return "buysell.status.failed"
        }
    }
    
    @ViewBuilder
    func getView() -> some View {
        if case .processing = self {
            HStack(alignment: .center, spacing: 5) {
                Text("Processing")
                    .font(.body.bold())
                ProgressView()
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .center)
        }
        
        if case .success = self {
            Text("Success")
                .font(.body.bold())
                .padding()
                .frame(maxWidth: .infinity, alignment: .center)
        }
        
        if case .failed = self {
            Text("Failed")
                .font(.body.bold())
                .padding()
                .frame(maxWidth: .infinity, alignment: .center)
        }
    }
    
    func getColor() -> Color {
        switch self {
        case .initialize: return .blue
        case .processing: return Color(UIColor.Background.content)
        case .success: return .green
        case .failed: return .red
        }
    }
}
