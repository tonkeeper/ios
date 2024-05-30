//
//  SwiftUIView.swift
//  
//
//  Created by davidtam on 23/5/24.
//

import SwiftUI
import Kingfisher
import TKUIKit

struct SwapConfirm: View {
    @Environment(\.presentationMode) var presentation
    @EnvironmentObject var vm: SwapVM
    
    @State var swapStatus: SwapStatus = .ready
    
    @ViewBuilder
    func buildHeader() -> some View {
        HeaderView {
            Text("Confirm Swap")
                .font(.title3.bold())
        } right: {
            SwiftUI.Image(uiImage: UIImage.TKUIKit.Icons.Size32.xmark)
                .resizable()
                .frame(width: 32, height: 32)
                .clipShape(Circle())
                .onTapGesture {
                    presentation.wrappedValue.dismiss()
                }
        }
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
                Spacer()
                Text("? USD")
            }
            .font(.callout)
            .foregroundColor(vm.secondaryLabel)
            
            HStack(alignment: .center) {
                Button {} label: {
                    HStack(alignment: .center, spacing: 4) {
                        buildTokenIcon(
                            width: 24,
                            urlString: vm.swapableAsset.first(where: {
                                $0.symbol?.uppercased() == vm.offerToken.uppercased()
                            })?.imageURL
                        )
                        Text(vm.offerToken.uppercased())
                            .font(.body.bold())
                            .foregroundColor(vm.mainLabel)
                    }
                    .padding(6)
                    .background(vm.layer3)
                    .clipShape(Capsule())
                }
                .foregroundColor(.white)
                
                Spacer()
                
                Text(vm.offerAmount)
                    .font(.title.bold())
                    .foregroundColor(vm.mainLabel)
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
                Spacer()
                Text("? USD")
            }
            .font(.callout)
            .foregroundColor(vm.secondaryLabel)
            
            HStack(alignment: .center) {
                Button {} label: {
                    HStack(alignment: .center, spacing: 4) {
                        buildTokenIcon(
                            width: 24,
                            urlString: vm.swapableAsset.first(where: {
                                $0.symbol?.uppercased() == vm.askToken.uppercased()
                            })?.imageURL
                        )
                        Text(vm.askToken.uppercased())
                            .font(.body.bold())
                            .foregroundColor(vm.mainLabel)
                    }
                    .padding(6)
                    .background(vm.layer3)
                    .clipShape(Capsule())
                }
                .foregroundColor(.white)
                
                Spacer()
                
                Text(vm.simutale?.getAskUnits() ?? "~")
                    .font(.title.bold())
                    .foregroundColor(vm.mainLabel)
            }
            
            Divider()
            
            vm.simutale?.buildView(mainLabel: vm.mainLabel, secondaryLabel: vm.secondaryLabel,
                                   askToken: vm.askToken, feeToken: vm.offerToken)
        }
        .padding()
        .background(vm.layer2)
        .clipShape(RoundedRectangle(cornerRadius: vm.cornerRadius, style: .continuous))
    }
    
    @ViewBuilder
    func buildConfirmCancel() -> some View {
        if case .ready = swapStatus {
            HStack(alignment: .center, spacing: 16) {
                Text("Cancel")
                    .font(.headline.bold())
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(vm.layer2)
                    .clipShape(RoundedRectangle(cornerRadius: vm.cornerRadius, style: .continuous))
                    .onTapGesture {
                        vm.mediumFeedback?.impactOccurred()
                        presentation.wrappedValue.dismiss()
                    }
                
                Text("Confirm")
                    .font(.headline.bold())
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(vm.main)
                    .clipShape(RoundedRectangle(cornerRadius: vm.cornerRadius, style: .continuous))
                    .onTapGesture {
                        vm.mediumFeedback?.impactOccurred()
                        
                        swapStatus = .loading
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1, execute: {
                            withAnimation {
                                swapStatus = .success
                            }
                        })
                    }
            }
        }
        
        if case .loading = swapStatus {
            Text("Loading ...")
                .font(.callout.bold())
                .frame(maxWidth: .infinity, alignment: .center)
                .padding()
        }
        
        if case .success = swapStatus {
            VStack(alignment: .center, spacing: 6) {
                SwiftUI.Image(uiImage: UIImage.TKUIKit.Icons.Size28.done)
                    .resizable()
                    .frame(width: 28, height: 28)
                    .clipShape(Circle())
                
                Text("Done")
                    .font(.body.bold())
                    .frame(maxWidth: .infinity, alignment: .center)
            }
            .foregroundColor(Color(UIColor.Accent.green))
        }
    }
    
    var body: some View {
        ZStack {
            vm.layer1.ignoresSafeArea()
            
            VStack(alignment: .leading, spacing: 16) {
                buildHeader()
                
                VStack(alignment: .leading, spacing: 10) {
                    buildFromAssetView()
                    buildToAssetView()
                }

                Spacer()
                buildConfirmCancel()
            }
            .navigationBarBackButtonHidden(true)
            
            .background(vm.layer1)
            .padding()
            
            .contentShape(Rectangle())
            .onTapGesture {
                hideKeyboard()
            }
        }
    }
}

#Preview {
    SwapConfirm()
}
