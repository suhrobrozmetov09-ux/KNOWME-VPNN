import Flutter
import NetworkExtension

public class KnowmeVpnPlugin: NSObject, FlutterPlugin, FlutterStreamHandler {

    private var sink: FlutterEventSink?
    private var manager: NETunnelProviderManager?
    private var observer: NSObjectProtocol?

    public static func register(with registrar: FlutterPluginRegistrar) {
        let instance = KnowmeVpnPlugin()
        let channel = FlutterMethodChannel(name: "knowme/vpn", binaryMessenger: registrar.messenger())
        registrar.addMethodCallDelegate(instance, channel: channel)
        let events = FlutterEventChannel(name: "knowme/vpn/status", binaryMessenger: registrar.messenger())
        events.setStreamHandler(instance)
    }

    override init() {
        super.init()
        observer = NotificationCenter.default.addObserver(
            forName: .NEVPNStatusDidChange, object: nil, queue: .main) { [weak self] _ in
            self?.emit()
        }
    }

    deinit {
        if let o = observer { NotificationCenter.default.removeObserver(o) }
    }

    // MARK: - Flutter method channel

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "start":
            guard let args = call.arguments as? [String: Any],
                  let conf = args["conf"] as? String,
                  let server = args["server"] as? String else {
                result(FlutterError(code: "args", message: "conf/server kerak", details: nil))
                return
            }
            start(conf: conf, server: server, result: result)
        case "stop":
            manager?.connection.stopVPNTunnel()
            result(nil)
        case "status":
            result(map(manager?.connection.status ?? .disconnected))
        default:
            result(FlutterMethodNotImplemented)
        }
    }

    // MARK: - Event channel

    public func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        sink = events
        loadManager { [weak self] _, _ in
            DispatchQueue.main.async { self?.emit() }
        }
        return nil
    }

    public func onCancel(withArguments arguments: Any?) -> FlutterError? {
        sink = nil
        return nil
    }

    // MARK: - Helpers

    private func emit() {
        sink?(map(manager?.connection.status ?? .disconnected))
    }

    private func map(_ s: NEVPNStatus) -> String {
        switch s {
        case .connected: return "connected"
        case .connecting, .reasserting: return "connecting"
        case .disconnecting: return "disconnecting"
        default: return "disconnected"
        }
    }

    /// Imzolash xizmati bundle ID'ni o'zgartirsa ham ishlashi uchun
    /// extension ID'sini PlugIns/ papkasidan o'qiymiz.
    private func extensionBundleId() -> String {
        if let plugins = Bundle.main.builtInPlugInsPath,
           let items = try? FileManager.default.contentsOfDirectory(atPath: plugins) {
            for item in items where item.hasSuffix(".appex") {
                if let b = Bundle(path: (plugins as NSString).appendingPathComponent(item)),
                   let id = b.bundleIdentifier {
                    return id
                }
            }
        }
        return (Bundle.main.bundleIdentifier ?? "") + ".WGExtension"
    }

    private func loadManager(_ done: @escaping (NETunnelProviderManager?, Error?) -> Void) {
        NETunnelProviderManager.loadAllFromPreferences { [weak self] managers, error in
            if let error = error {
                done(nil, error)
                return
            }
            let m = managers?.first ?? NETunnelProviderManager()
            self?.manager = m
            done(m, nil)
        }
    }

    private func start(conf: String, server: String, result: @escaping FlutterResult) {
        func fail(_ code: String, _ err: Error?) {
            DispatchQueue.main.async {
                result(FlutterError(code: code, message: err?.localizedDescription ?? code, details: nil))
            }
        }
        loadManager { [weak self] m, err in
            guard let self = self, let m = m else { fail("load", err); return }

            let proto = NETunnelProviderProtocol()
            proto.providerBundleIdentifier = self.extensionBundleId()
            proto.serverAddress = server
            proto.providerConfiguration = ["wgQuickConfig": conf]

            m.protocolConfiguration = proto
            m.localizedDescription = "KNOWME VPN"
            m.isEnabled = true

            m.saveToPreferences { saveErr in
                if let saveErr = saveErr { fail("save", saveErr); return }
                // Birinchi saqlashdan keyin qayta yuklash shart
                m.loadFromPreferences { loadErr in
                    if let loadErr = loadErr { fail("reload", loadErr); return }
                    do {
                        try m.connection.startVPNTunnel()
                        DispatchQueue.main.async { result(nil) }
                    } catch {
                        fail("start", error)
                    }
                }
            }
        }
    }
}
