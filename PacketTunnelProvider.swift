import NetworkExtension
import WireGuardKit

enum TunnelError: Error {
    case missingConfig
    case badConfig
}

class PacketTunnelProvider: NEPacketTunnelProvider {

    private lazy var adapter: WireGuardAdapter = {
        return WireGuardAdapter(with: self) { _, message in
            NSLog("KNOWME-WG: %@", message)
        }
    }()

    override func startTunnel(options: [String: NSObject]?,
                              completionHandler: @escaping (Error?) -> Void) {
        guard let proto = protocolConfiguration as? NETunnelProviderProtocol,
              let conf = proto.providerConfiguration?["wgQuickConfig"] as? String else {
            completionHandler(TunnelError.missingConfig)
            return
        }
        guard let tunnelConfig = try? TunnelConfiguration(fromWgQuickConfig: conf, called: "KNOWME") else {
            completionHandler(TunnelError.badConfig)
            return
        }
        adapter.start(tunnelConfiguration: tunnelConfig) { adapterError in
            if let adapterError = adapterError {
                NSLog("KNOWME-WG: start error %@", String(describing: adapterError))
                completionHandler(adapterError)
            } else {
                completionHandler(nil)
            }
        }
    }

    override func stopTunnel(with reason: NEProviderStopReason,
                             completionHandler: @escaping () -> Void) {
        adapter.stop { error in
            if let error = error {
                NSLog("KNOWME-WG: stop error %@", String(describing: error))
            }
            completionHandler()
        }
    }
}
