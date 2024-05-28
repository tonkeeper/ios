//
//  SwiftUIView.swift
//  
//
//  Created by davidtam on 24/5/24.
//

import SwiftUI
import TKUIKit

enum LoadingStatus {
    case loading
    case failure
    case success
    
    @ViewBuilder
    func buildView() -> some View {
        switch self {
        case .loading: Text("loading")
        case .failure: Text("failure")
        case .success:
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
}

struct StakeConfirm: View {
    @Environment(\.presentationMode) var presentation
    @EnvironmentObject var vm: StakeViewModel
    
    @State var isLocked: Bool = true
    @State var status: LoadingStatus = .loading
    
    @ViewBuilder
    func buildHeader() -> some View {
        HeaderView {
            EmptyView()
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
    func buildStakingPreview() -> some View {
        VStack(alignment: .center, spacing: 16) {
            if let image = vm.selectedStaking.lowercased().getImage() {
                SwiftUI.Image(uiImage: image)
                    .resizable()
                    .frame(width: 92, height: 92)
                    .clipShape(Circle())
            } else {
                vm.layer2
                    .frame(width: 92, height: 92)
                    .clipShape(Circle())
            }
            
            VStack(alignment: .center, spacing: 4) {
                Text("Deposit / Unstake")
                    .font(.callout)
                    .foregroundColor(vm.secondaryLabel)
                
                HStack(alignment: .center) {
                    Text(vm.stakingDetail["Recipient"]?.asProvider() ?? "Provider ?")
                    Text("TON")
                }
                .font(.title3.bold())
                .foregroundColor(vm.mainLabel)
                
                Text("$ ?")
                    .font(.callout)
                    .foregroundColor(vm.secondaryLabel)
            }
        }
        .padding(.vertical, 16)
        .frame(maxWidth: .infinity, alignment: .center)
    }
    
    @ViewBuilder func buildStakingDetail() -> some View {
        VStack(spacing: 12) {
            ForEach(vm.stakingDetail.sorted(by: >), id: \.key) { key, value in
                HStack {
                    Text(key)
                        .font(.callout.bold())
                        .foregroundColor(vm.secondaryLabel)
                    
                    Spacer()
                    
                    Text(value)
                        .font(.callout.bold())
                        .foregroundColor(vm.mainLabel)
                }
                .frame(maxWidth: .infinity)
                
                Divider()
            }
        }
        .padding()
        .background(vm.layer2)
        .clipShape(RoundedRectangle(cornerRadius: vm.cornerRadius, style: .continuous))
    }
    
    private func simulateRequest() {
        status = .loading
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            withAnimation {
                status = .success
            }
        }
    }
    
    var body: some View {
        ZStack {
            vm.layer1.ignoresSafeArea()
            
            VStack(alignment: .leading, spacing: 16) {
                buildHeader()
                ScrollView {
                    buildStakingPreview()
                    buildStakingDetail()
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
            
            .onChange(of: isLocked) { isLocked in
                guard !isLocked else { return }
                simulateRequest()
            }
            
            VStack {
                Spacer()
                
                if isLocked {
                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            BackgroundComponent(color: vm.layer2, secondaryLabel: vm.secondaryLabel)
                            DraggingComponent(
                                isLocked: $isLocked, isLoading: false,
                                maxWidth: geometry.size.width,
                                main: vm.main,
                                layer2: vm.layer2,
                                mainLabel: vm.mainLabel,
                                secondaryLabel: vm.secondaryLabel
                            )
                        }
                    }
                    .frame(height: 56)
                } else {
                    status.buildView()
                        .foregroundColor(vm.mainLabel)
                        .font(.headline.bold())
                        .frame(maxWidth: .infinity)
                        .padding()
                }
            }
            .padding()
        }
    }
}

#Preview {
    NavigationView {
        StakeConfirm()
            .environmentObject(StakeViewModel())
    }
}
