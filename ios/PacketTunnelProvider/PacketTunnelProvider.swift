import NetworkExtension

final class PacketTunnelProvider: NEPacketTunnelProvider {
  private var isTurnMode = true

  override func startTunnel(
    options: [String : NSObject]?,
    completionHandler: @escaping (Error?) -> Void
  ) {
    if let mode = options?["useTurnMode"] as? NSNumber {
      isTurnMode = mode.boolValue
    }
    // Full native implementation point:
    // 1) Initialize WireGuardKit adapter with provided config
    // 2) If isTurnMode == true, attach TURN transport path
    // 3) Apply tunnel network settings (routes, DNS)
    completionHandler(nil)
  }

  override func stopTunnel(with reason: NEProviderStopReason, completionHandler: @escaping () -> Void) {
    completionHandler()
  }
}
