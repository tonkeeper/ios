//
//  SwiftUIView.swift
//  
//
//  Created by davidtam on 24/5/24.
//

import SwiftUI
import TKUIKit

struct StakeProviderList: View {
    @Environment(\.presentationMode) var presentation
    @EnvironmentObject var vm: StakeViewModel
    
    @Binding var provider: String
    
    @ViewBuilder
    func buildHeader() -> some View {
        HeaderView {
            Text(provider.asProvider() ?? "?")
                .font(.title3.bold())
        } left: {
            SwiftUI.Image(uiImage: UIImage.TKUIKit.Icons.Size32.chevronLeft)
                .resizable()
                .frame(width: 32, height: 32)
                .clipShape(Circle())
                .onTapGesture {
                    presentation.wrappedValue.dismiss()
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
    }
    
    @ViewBuilder
    func buildLiquidRow(asset: String, tag: String?) -> some View {
        HStack(alignment: .center, spacing: 16) {
            NavigationLink {
                StakeProvider(
                    provider: .constant(asset),
                    infoDict: .constant(["APY":"~5%", "Minimal deposit":"1 TON"]),
                    didTapChoose: { asset in
                        vm.selectedStaking = asset
                        vm.stakingDetail["Recipient"] = asset
                    }
                )
                .environmentObject(vm)
            } label: {
                if let icon = asset.lowercased().getImage() {
                    SwiftUI.Image(uiImage: icon)
                        .resizable()
                        .frame(width: 44, height: 44)
                        .clipShape(Circle())
                } else {
                    vm.layer2
                        .frame(width: 44, height: 44)
                        .clipShape(Circle())
                }
                
                VStack(alignment: .leading, spacing: 6) {
                    HStack(alignment: .center, spacing: 8) {
                        Text(asset.asProvider() ?? "~")
                            .font(.headline.bold())
                            .foregroundColor(vm.mainLabel)
                        
                        if let tag {
                            Text(tag)
                                .font(.system(size: 8, weight: .bold, design: .rounded))
                                .padding(4)
                                .foregroundColor(Color.green)
                                .background(Color.green.opacity(0.3))
                                .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
                        }
                    }
                    
                    HStack(alignment: .center, spacing: 4) {
                        Text("APY ~ 5%")
                        Text("-")
                        Text("? TON")
                    }
                    .font(.caption)
                    .foregroundColor(vm.secondaryLabel)
                }
            }
            
            Spacer()
            
            Group {
                if asset == vm.selectedStaking {
                    SwiftUI.Image(uiImage: .TKUIKit.Icons.Size28.radioSelected)
                        .foregroundColor(Color(UIColor.Button.primaryBackground))
                } else {
                    SwiftUI.Image(uiImage: .TKUIKit.Icons.Size28.radioUnselect)
                        .foregroundColor(Color(UIColor.Button.tertiaryBackground))
                }
            }
            .clipShape(Circle())
            .onTapGesture {
                vm.selectedStaking = asset
                vm.stakingDetail["Recipient"] = asset
            }
        }
    }
    
    @ViewBuilder
    func buildLiquidStaking() -> some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(spacing: 0) {
                ForEach(vm.childStakingOptions, id: \.description) { item in
                    buildLiquidRow(asset: item, tag: item == vm.liquidStakingOptions.first! ? "MAX APY" : nil)
                        .padding(16)
                    
                    Divider()
                }
            }
            .background(vm.layer2)
            .clipShape(RoundedRectangle(cornerRadius: vm.cornerRadius, style: .continuous))
        }
    }
    
    var body: some View {
        ZStack {
            vm.layer1.ignoresSafeArea()
            
            VStack(alignment: .leading, spacing: 16) {
                buildHeader()
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        buildLiquidStaking()
                    }
                }
                
                Spacer()
            }
            .navigationBarBackButtonHidden(true)
            
            .background(vm.layer1)
            .padding([.top, .horizontal])
            
            .contentShape(Rectangle())
            .onTapGesture {
                hideKeyboard()
            }
        }
    }
}

#Preview {
    StakeProviderList(provider: .constant("Provider ?"))
        .environmentObject(StakeViewModel())
}
