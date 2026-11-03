import 'dart:io';

import 'package:flutter/services.dart';
import 'package:wireguard_flutter_plus/wireguard_flutter_plus.dart';

/// iOS: o'z native ko'prigimiz (packet tunnel extension).
/// Android: wireguard_flutter_plus plagini.
class VpnService {
  static const MethodChannel _method = MethodChannel('knowme/vpn');
  static const EventChannel _events = EventChannel('knowme/vpn/status');

  late final WireGuardFlutter _wg = WireGuardFlutter.instance;
  bool get _ios => Platform.isIOS;

  Future<void> initialize() async {
    if (!_ios) {
      await _wg.initialize(interfaceName: 'wg0', vpnName: 'KNOWME VPN');
    }
  }

  Stream<String> get stageStream {
    if (_ios) {
      return _events
          .receiveBroadcastStream()
          .map((e) => e.toString().toLowerCase());
    }
    return _wg.vpnStageSnapshot
        .map((e) => e.toString().split('.').last.toLowerCase());
  }

  Future<void> start(String server, String conf) async {
    if (_ios) {
      await _method.invokeMethod('start', {'server': server, 'conf': conf});
    } else {
      await _wg.startVpn(
        serverAddress: server,
        wgQuickConfig: conf,
        providerBundleIdentifier: 'com.knowme.knowmeVpn.WGExtension',
      );
    }
  }

  Future<void> stop() async {
    if (_ios) {
      await _method.invokeMethod('stop');
    } else {
      await _wg.stopVpn();
    }
  }
}
