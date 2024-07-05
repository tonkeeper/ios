import Foundation
import TonSwift

public final class CollectibleDetailsController {
  
  public var didUpdateModel: ((CollectibleDetailsModel) -> Void)?
  
  public let nft: NFT
  private let walletsStore: WalletsStore
  private let nftService: NFTService
  private let dnsService: DNSService
  private let collectibleDetailsMapper: CollectibleDetailsMapper
  
  init(nft: NFT,
       walletsStore: WalletsStore,
       nftService: NFTService,
       dnsService: DNSService,
       collectibleDetailsMapper: CollectibleDetailsMapper) {
    self.nft = nft
    self.walletsStore = walletsStore
    self.nftService = nftService
    self.dnsService = dnsService
    self.collectibleDetailsMapper = collectibleDetailsMapper
  }
  
  public func prepareCollectibleDetails() throws {
    let model = buildInitialViewModel(nft: nft)
    didUpdateModel?(model)
    guard nft.dns != nil else { return }
    Task {
      async let linkedAddressTask = getDNSLinkedAddress(nft: nft)
      async let expirationDateTask = getDNSExpirationDate(nft: nft)
      
      let linkedAddress = try? await linkedAddressTask
      let expirationDate = try? await expirationDateTask
      
      let model = buildDNSInfoLoadedViewModel(
        nft: nft,
        linkedAddress: linkedAddress,
        expirationDate: expirationDate)
      
      await MainActor.run {
        didUpdateModel?(model)
      }
    }
  }
}

private extension CollectibleDetailsController {
  func buildInitialViewModel(nft: NFT) -> CollectibleDetailsModel {
    return collectibleDetailsMapper.map(
      nft: nft,
      isOwner: isOwner(nft),
      isActionsAvailable: isActionsAvailable(),
      linkedAddress: nil,
      expirationDate: nil,
      isInitial: true)
  }
  
  func buildDNSInfoLoadedViewModel(nft: NFT,
                                   linkedAddress: FriendlyAddress?,
                                   expirationDate: Date?) -> CollectibleDetailsModel {
    return collectibleDetailsMapper.map(
      nft: nft,
      isOwner: isOwner(nft),
      isActionsAvailable: isActionsAvailable(),
      linkedAddress: linkedAddress,
      expirationDate: expirationDate,
      isInitial: false)
  }
  
  func isOwner(_ nft: NFT) -> Bool {
    guard let address = try? walletsStore.activeWallet.address else { return false }
    return nft.owner?.address == address
  }
  
  func isActionsAvailable() -> Bool {
    switch walletsStore.activeWallet.kind {
    case .ledger, .watchonly:
      return false
    default:
      return true
    }
  }
  
  func getDNSLinkedAddress(nft: NFT) async throws -> FriendlyAddress? {
    guard let dns = nft.dns else { return nil }
    let linkedAddress = try await dnsService.resolveDomainName(
      dns,
      isTestnet: walletsStore.activeWallet.isTestnet
    )
    return linkedAddress.friendlyAddress
  }
  
  func getDNSExpirationDate(nft: NFT) async throws -> Date? {
    guard let dns = nft.dns else { return nil }
    let date = try await dnsService.loadDomainExpirationDate(
      dns,
      isTestnet: walletsStore.activeWallet.isTestnet
    )
    return date
  }
}
