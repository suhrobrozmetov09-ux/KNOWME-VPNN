import 'dart:async';
import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:wireguard_flutter_plus/wireguard_flutter_plus.dart';

void main() => runApp(const KnowmeApp());

const kRed = Color(0xFFFF3038);
const kBg = Color(0xFF090909);
const kPanel = Color(0xFF171717);
const kExtensionBundleId = 'com.knowme.vpn.WGExtension';

class KnowmeApp extends StatelessWidget {
  const KnowmeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'KNOWME VPN',
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: kBg,
        colorScheme: const ColorScheme.dark(
          primary: kRed,
          secondary: kRed,
          surface: kPanel,
        ),
        fontFamily: 'Arial',
        useMaterial3: true,
      ),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final _wireguard = WireGuardFlutter.instance;
  StreamSubscription<dynamic>? _stageSubscription;

  String? _config;
  String? _endpoint;
  String _status = 'DISCONNECTED';
  String _selectedServer = 'No server imported';
  bool _busy = false;

  bool get _connected => _status.toLowerCase().contains('connected') &&
      !_status.toLowerCase().contains('disconnected');

  @override
  void initState() {
    super.initState();
    _listenForStatus();
  }

  void _listenForStatus() {
    _stageSubscription = _wireguard.vpnStageSnapshot.listen((stage) {
      if (!mounted) return;
      setState(() => _status = stage.toString().split('.').last.toUpperCase());
    });
  }

  String? _readEndpoint(String config) {
    final match = RegExp(
      r'^\s*Endpoint\s*=\s*(\S+)',
      multiLine: true,
      caseSensitive: false,
    ).firstMatch(config);
    return match?.group(1);
  }

  Future<void> _importConfig() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['conf'],
        withData: true,
      );
      if (result == null || result.files.isEmpty) return;

      final file = result.files.single;
      final bytes = file.bytes;
      if (bytes == null) {
        _showMessage('Could not read this file. Please try another .conf file.');
        return;
      }

      final config = utf8.decode(bytes, allowMalformed: false);
      if (!config.contains('[Interface]') || !config.contains('[Peer]')) {
        _showMessage('This does not look like a WireGuard configuration.');
        return;
      }

      final endpoint = _readEndpoint(config);
      if (endpoint == null || !endpoint.contains(':')) {
        _showMessage('The configuration is missing a valid Endpoint.');
        return;
      }

      setState(() {
        _config = config;
        _endpoint = endpoint;
        _selectedServer = endpoint;
      });
      _showMessage('Configuration imported. Keep it private.');
    } on FormatException {
      _showMessage('The configuration file is not valid UTF-8 text.');
    } catch (e) {
      _showMessage('Import failed: $e');
    }
  }

  Future<void> _toggleVpn() async {
    if (_busy) return;
    if (_connected) {
      await _disconnect();
      return;
    }
    if (_config == null || _endpoint == null) {
      _showMessage('Import a WireGuard .conf file first.');
      return;
    }

    setState(() {
      _busy = true;
      _status = 'CONNECTING';
    });

    try {
      await _wireguard.initialize(
        interfaceName: 'wg0',
        vpnName: 'KNOWME VPN',
      );
      await _wireguard.startVpn(
        serverAddress: _endpoint!,
        wgQuickConfig: _config!,
        providerBundleIdentifier: kExtensionBundleId,
      );
      if (mounted) {
        setState(() => _status = 'CONNECTING');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _status = 'DISCONNECTED');
      }
      _showMessage('VPN could not start. Check platform setup and config.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _disconnect() async {
    setState(() {
      _busy = true;
      _status = 'DISCONNECTING';
    });
    try {
      await _wireguard.stopVpn();
      if (mounted) setState(() => _status = 'DISCONNECTED');
    } catch (e) {
      _showMessage('Disconnect failed: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: const Color(0xFF292929),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  void dispose() {
    _stageSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final statusColor = _connected ? Colors.greenAccent : kRed;
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 18, 22, 12),
              child: Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: kRed,
                      borderRadius: BorderRadius.circular(13),
                    ),
                    child: const Icon(Icons.bolt_rounded,
                        color: Colors.white, size: 28),
                  ),
                  const SizedBox(width: 12),
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('KNOWME',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 2,
                          )),
                      Text('VPN', style: TextStyle(
                        color: kRed,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 4,
                      )),
                    ],
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: _importConfig,
                    tooltip: 'Import config',
                    icon: const Icon(Icons.add_circle_outline,
                        color: Colors.white70, size: 27),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 22),
              padding: const EdgeInsets.all(17),
              decoration: BoxDecoration(
                color: kPanel,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white.withOpacity(.06)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.shield_outlined, color: kRed, size: 28),
                  const SizedBox(width: 13),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('CONNECTION STATUS',
                            style: TextStyle(
                              color: Colors.white54,
                              fontSize: 10,
                              letterSpacing: 1.5,
                              fontWeight: FontWeight.bold,
                            )),
                        const SizedBox(height: 5),
                        Text(_status,
                            style: TextStyle(
                              color: statusColor,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.2,
                            )),
                      ],
                    ),
                  ),
                  Container(
                    width: 9,
                    height: 9,
                    decoration: BoxDecoration(
                      color: statusColor,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(color: statusColor.withOpacity(.6), blurRadius: 9)
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const Spacer(),
            GestureDetector(
              onTap: _busy ? null : _toggleVpn,
              child: Container(
                width: 218,
                height: 218,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      kRed.withOpacity(.25),
                      kRed.withOpacity(.08),
                      kBg,
                    ],
                    stops: const [0, .65, 1],
                  ),
                  border: Border.all(color: kRed.withOpacity(.55), width: 1.5),
                  boxShadow: [
                    BoxShadow(
                      color: kRed.withOpacity(.18),
                      blurRadius: 38,
                      spreadRadius: 5,
                    ),
                  ],
                ),
                child: Center(
                  child: Container(
                    width: 150,
                    height: 150,
                    decoration: BoxDecoration(
                      color: kRed,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: kRed.withOpacity(.35),
                          blurRadius: 25,
                          spreadRadius: 2,
                        )
                      ],
                    ),
                    child: _busy
                        ? const Center(
                            child: CircularProgressIndicator(color: Colors.white))
                        : Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(_connected ? Icons.power_settings_new : Icons.bolt,
                                  color: Colors.white, size: 43),
                              const SizedBox(height: 5),
                              Text(_connected ? 'DISCONNECT' : 'CONNECT',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 1.5,
                                  )),
                            ],
                          ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              _connected ? 'Your tunnel is active' : 'Tap to connect securely',
              style: const TextStyle(color: Colors.white54, fontSize: 13),
            ),
            const Spacer(),
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 0, 22, 25),
              child: Container(
                padding: const EdgeInsets.all(17),
                decoration: BoxDecoration(
                  color: kPanel,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: Colors.white.withOpacity(.06)),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.public, color: kRed),
                        const SizedBox(width: 10),
                        const Expanded(
                          child: Text('SELECTED SERVER',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 11,
                                letterSpacing: 1.2,
                              )),
                        ),
                        TextButton(
                          onPressed: _importConfig,
                          child: const Text('IMPORT .CONF',
                              style: TextStyle(color: kRed, fontSize: 11)),
                        ),
                      ],
                    ),
                    const Divider(color: Colors.white12, height: 18),
                    Row(
                      children: [
                        const Icon(Icons.dns_outlined,
                            color: Colors.white54, size: 20),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            _selectedServer,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 13),
                          ),
                        ),
                        Icon(
                          _config == null ? Icons.warning_amber_rounded : Icons.check_circle,
                          color: _config == null ? Colors.orangeAccent : Colors.greenAccent,
                          size: 18,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
