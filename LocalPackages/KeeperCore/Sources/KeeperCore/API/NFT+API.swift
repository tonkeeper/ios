import Foundation
import TonAPI
import TonSwift

extension NFT {
    private enum PreviewSize: String {
        case size5 = "5x5"
        case size100 = "100x100"
        case size500 = "500x500"
        case size1500 = "1500x1500"
    }

    init(nftItem: TonAPI.Components.Schemas.NftItem) throws {
        let address = try Address.parse(nftItem.address)
        var owner: WalletAccount?
        var name: String?
        var imageURL: URL?
        var description: String?
        var collection: NFTCollection?
        var lottieURL: URL?

        if let ownerAccountAddress = nftItem.owner,
           let ownerWalletAccount = try? WalletAccount(accountAddress: ownerAccountAddress)
        {
            owner = ownerWalletAccount
        }

        let metadata = nftItem.metadata.additionalProperties.value
        name = metadata["name"] as? String
        imageURL = (metadata["image"] as? String).flatMap { URL(string: $0) }
        lottieURL = (metadata["lottie"] as? String).flatMap { URL(string: $0) }
        description = metadata["description"] as? String
        let renderType: RenderType? = {
            if let apiRenderType = metadata["render_type"] as? String,
               let renderType = RenderType(rawValue: apiRenderType)
            {
                return renderType
            } else {
                return nil
            }
        }()

        var attributes = [Attribute]()
        if let attributesValue = metadata["attributes"] as? [(any Sendable)?] {
            attributes = attributesValue
                .compactMap { $0 as? [String: (any Sendable)?] }
                .compactMap { attributeObject -> Attribute? in
                    guard let key = attributeObject["trait_type"] as? String else { return nil }
                    let attributeValue: String
                    switch attributeObject["value"] ?? nil {
                    case .none: return nil
                    case let .some(value):
                        switch value {
                        case let stringValue as String:
                            attributeValue = stringValue
                        case let intValue as Int:
                            attributeValue = String(intValue)
                        case let doubleValue as Double:
                            attributeValue = String(doubleValue)
                        default:
                            attributeValue = "-"
                        }
                    }
                    return Attribute(key: key, value: attributeValue)
                }
        }

        if let nftCollection = nftItem.collection,
           let address = try? Address.parse(nftCollection.address)
        {
            collection = NFTCollection(address: address, name: nftCollection.name, description: nftCollection.description)
        }

        if imageURL == nil,
           let previewURLString = nftItem.previews?[2].url,
           let previewURL = URL(string: previewURLString)
        {
            imageURL = previewURL
        }

        var sale: Sale?
        if let nftSale = nftItem.sale {
            let address = try Address.parse(nftSale.address)
            let market = try WalletAccount(accountAddress: nftSale.market)
            var ownerWalletAccount: WalletAccount?
            if let nftSaleOwner = nftItem.owner {
                ownerWalletAccount = try WalletAccount(accountAddress: nftSaleOwner)
            }
            sale = Sale(address: address, market: market, owner: ownerWalletAccount)
        }

        let trust: Trust = {
            switch nftItem.trust {
            case .none: return .none
            case .blacklist: return .blacklist
            case .graylist: return .graylist
            case .whitelist: return .whitelist
            case .unknown: return .unknown
            }
        }()

        var buttons: [Button]?
        if let metadataButtons = metadata["buttons"] as? [(any Sendable)?] {
            buttons = metadataButtons
                .compactMap { $0 as? [String: (any Sendable)?] }
                .map { metaButton -> Button in
                    let label = metaButton["label"] as? String
                    let style = metaButton["style"] as? String
                    var url: URL?
                    if let stringURL = metaButton["uri"] as? String,
                       let resultURL = URL(string: stringURL)
                    {
                        url = resultURL
                    }

                    return Button(label: label, style: style, url: url)
                }
        }

        self.address = address
        self.owner = owner
        self.name = name
        self.imageURL = imageURL
        self.lottieURL = lottieURL
        self.description = description
        self.attributes = attributes
        self.preview = Self.mapPreviews(nftItem.previews)
        self.collection = collection
        self.dns = nftItem.dns
        self.programmaticButtons = buttons
        self.sale = sale
        self.trust = trust
        self.renderType = renderType
    }

    private static func mapPreviews(_ previews: [TonAPI.Components.Schemas.ImagePreview]?) -> Preview {
        var size5: URL?
        var size100: URL?
        var size500: URL?
        var size1500: URL?

        previews?.forEach { preview in
            guard let previewSize = PreviewSize(rawValue: preview.resolution) else { return }
            switch previewSize {
            case .size5:
                size5 = URL(string: preview.url)
            case .size100:
                size100 = URL(string: preview.url)
            case .size500:
                size500 = URL(string: preview.url)
            case .size1500:
                size1500 = URL(string: preview.url)
            }
        }
        return Preview(size5: size5, size100: size100, size500: size500, size1500: size1500)
    }
}
