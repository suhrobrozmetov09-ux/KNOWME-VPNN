
import 'dart:async';
import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:wireguard_flutter_plus/wireguard_flutter_plus.dart';

void main() => runApp(const KnowmeApp());

const red = Color(0xFFFF3038);
const bg = Color(0xFF090909);
const panel = Color(0xFF171717);
const extensionId = 'com.knowme.vpn.WGExtension';

class VpnServer {
  final String name;
  final String config;
  final String endpoint;

  const VpnServer({
    required this.name,
    required this.config,
    required this.endpoint,
  });
}

class KnowmeApp extends StatelessWidget {
  const KnowmeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'KNOWME VPN',
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: bg,
        colorScheme: const ColorScheme.dark(primary: red),
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
  final wireguard = WireGuardFlutter.instance;
  StreamSubscription<dynamic>? subscription;

  final List<VpnServer> servers = [];
  int selectedIndex = 0;
  String status = 'DISCONNECTED';
  bool busy = false;

  VpnServer? get selected =>
      servers.isEmpty ? null : servers[selectedIndex];

  bool get connected {
    final s = status.toLowerCase();
    return s.contains('connected') && !s.contains('disconnected');
  }

  @override
  void initState() {
    super.initState();
    subscription = wireguard.vpnStageSnapshot.listen((stage) {
      if (!mounted) return;
      setState(() {
        status = stage.toString().split('.').last.toUpperCase();
      });
    });
  }

  String? readEndpoint(String config) {
    final match = RegExp(
      r'^\s*Endpoint\s*=\s*(\S+)',
      multiLine: true,
      caseSensitive: false,
    ).firstMatch(config);
    return match?.group(1);
  }

  Future<void> importConfigs() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['conf'],
        allowMultiple: true,
        withData: true,
      );

      if (result == null) return;

      int skipped = 0;
      int added = 0;

      for (final file in result.files) {
        if (file.bytes == null) {
          skipped++;
          continue;
        }

        try {
          final config = utf8.decode(file.bytes!);
          if (!config.contains('[Interface]') ||
              !config.contains('[Peer]')) {
            skipped++;
            continue;
          }

          final endpoint = readEndpoint(config);
          if (endpoint == null || !endpoint.contains(':')) {
            skipped++;
            continue;
          }

          final name = file.name.replaceAll(
            RegExp(r'\.conf$', caseSensitive: false),
            '',
          );

          final exists = servers.any(
            (s) => s.name == name && s.endpoint == endpoint,
          );

          if (!exists) {
            servers.add(VpnServer(
              name: name.isEmpty ? endpoint : name,
              config: config,
              endpoint: endpoint,
            ));
            added++;
          }
        } catch (_) {
          skipped++;
        }
      }

      if (!mounted) return;
      setState(() {
        if (selectedIndex >= servers.length) selectedIndex = 0;
      });

      message(
        '$added server added. Total: ${servers.length}. '
        'Skipped: $skipped',
      );
    } catch (_) {
      message('Could not import configuration files.');
    }
  }

  Future<void> toggleVpn() async {
    if (busy) return;

    if (connected) {
      await disconnectVpn();
      return;
    }

    final server = selected;
    if (server == null) {
      message('Import your .conf files first.');
      return;
    }

    setState(() {
      busy = true;
      status = 'CONNECTING';
    });

    try {
      await wireguard.initialize(
        interfaceName: 'wg0',
        vpnName: 'KNOWME VPN',
      );

      await wireguard.startVpn(
        serverAddress: server.endpoint,
        wgQuickConfig: server.config,
        providerBundleIdentifier: extensionId,
      );

      if (mounted) setState(() => status = 'CONNECTING');
    } catch (_) {
      if (mounted) setState(() => status = 'DISCONNECTED');
      message('VPN setup or Apple signing is not ready.');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> disconnectVpn() async {
    setState(() {
      busy = true;
      status = 'DISCONNECTING';
    });

    try {
      await wireguard.stopVpn();
      if (mounted) setState(() => status = 'DISCONNECTED');
    } catch (_) {
      message('Disconnect failed.');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  void message(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(text),
        backgroundColor: panel,
      ),
    );
  }

  @override
  void dispose() {
    subscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final server = selected;
    final statusColor = connected ? Colors.greenAccent : red;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(22),
              child: Row(
                children: [
                  const Icon(Icons.bolt, color: red, size: 38),
                  const SizedBox(width: 10),
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('KNOWME',
                          style: TextStyle(
                            fontSize: 21,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 2,
                          )),
                      Text('VPN',
                          style: TextStyle(
                            color: red,
                            letterSpacing: 4,
                            fontWeight: FontWeight.bold,
                          )),
                    ],
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: busy || connected ? null : importConfigs,
                    icon: const Icon(Icons.add_circle_outline),
                  ),
                ],
              ),
            ),
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 22),
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: panel,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Row(
                children: [
                  const Icon(Icons.shield, color: red, size: 28),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('CONNECTION STATUS',
                            style: TextStyle(
                              color: Colors.white54,
                              fontSize: 10,
                            )),
                        const SizedBox(height: 5),
                        Text(status,
                            style: TextStyle(
                              color: statusColor,
                              fontWeight: FontWeight.bold,
                            )),
                      ],
                    ),
                  ),
                  Icon(Icons.circle, color: statusColor, size: 10),
                ],
              ),
            ),
            const Spacer(),
            GestureDetector(
              onTap: busy ? null : toggleVpn,
              child: Container(
                width: 205,
                height: 205,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: red.withOpacity(.12),
                  border: Border.all(color: red, width: 2),
                ),
                child: Center(
                  child: Container(
                    width: 150,
                    height: 150,
                    decoration: const BoxDecoration(
                      color: red,
                      shape: BoxShape.circle,
                    ),
                    child: busy
                        ? const Center(
                            child: CircularProgressIndicator(
                              color: Colors.white,
                            ),
                          )
                        : Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                connected
                                    ? Icons.power_settings_new
                                    : Icons.bolt,
                                size: 43,
                                color: Colors.white,
                              ),
                              const SizedBox(height: 6),
                              Text(
                                connected ? 'DISCONNECT' : 'CONNECT',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ],
                          ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              connected ? 'Tunnel active' : 'Tap to connect',
              style: const TextStyle(color: Colors.white54),
            ),
            const Spacer(),
            Container(
              margin: const EdgeInsets.fromLTRB(20, 0, 20, 24),
              padding: const EdgeInsets.all(17),
              decoration: BoxDecoration(
                color: panel,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      const Icon(Icons.public, color: red),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Text(
                          'SELECT SERVER',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1,
                          ),
                        ),
                      ),
                      TextButton(
                        onPressed:
                            busy || connected ? null : importConfigs,
                        child: const Text(
                          'IMPORT .CONF',
                          style: TextStyle(color: red),
                        ),
                      ),
                    ],
                  ),
                  const Divider(color: Colors.white12),
                  if (servers.isEmpty)
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'No servers imported',
                        style: TextStyle(color: Colors.white54),
                      ),
                    )
                  else
                    DropdownButtonHideUnderline(
                      child: DropdownButton<int>(
                        value: selectedIndex,
                        isExpanded: true,
                        dropdownColor: panel,
                        items: List.generate(servers.length, (index) {
                          return DropdownMenuItem(
                            value: index,
                            child: Text(servers[index].name),
                          );
                        }),
                        onChanged: busy || connected
                            ? null
                            : (value) {
                                if (value != null) {
                                  setState(() => selectedIndex = value);
                                }
                              },
                      ),
                    ),
                  if (server != null) ...[
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        server.endpoint,
                        style: const TextStyle(
                          color: Colors.white38,
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      '${servers.length} server(s) imported',
                      style: const TextStyle(
                        color: Colors.white38,
                        fontSize: 11,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
