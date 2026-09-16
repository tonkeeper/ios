import KeeperCore

enum MultichainSendEntry {
    case enterAmount(MultichainSendInput)
    case tokenPicker(allowedChains: Set<MultichainChain>?, initialChain: MultichainChain?)
}
