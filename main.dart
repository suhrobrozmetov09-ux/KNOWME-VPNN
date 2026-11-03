import 'dart:async';
import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'vpn_service.dart';

import 'default_configs.dart';

void main() => runApp(const KnowmeApp());

class KnowmeApp extends StatelessWidget {
  const KnowmeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'KNOWME VPN',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorSchemeSeed: const Color(0xFF3DDC97),
      ),
      home: const HomePage(),
    );
  }
}

class VpnServer {
  final String name;
  final String conf;
  VpnServer(this.name, this.conf);

  String get endpoint {
    final m = RegExp(r'^\s*Endpoint\s*=\s*(\S+)',
            multiLine: true, caseSensitive: false)
        .firstMatch(conf);
    return m?.group(1) ?? '';
  }

  Map<String, String> toJson() => {'name': name, 'conf': conf};
  factory VpnServer.fromJson(Map<String, dynamic> j) =>
      VpnServer(j['name'] as String, j['conf'] as String);

  static bool isValid(String conf) =>
      conf.contains('[Interface]') &&
      conf.contains('[Peer]') &&
      RegExp(r'^\s*Endpoint\s*=', multiLine: true, caseSensitive: false)
          .hasMatch(conf);
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final _wg = VpnService();
  final List<VpnServer> _servers = [];
  int _selected = 0;
  String _stage = 'disconnected';
  bool _busy = false;
  bool _ready = false;
  StreamSubscription? _sub;

  bool get _connected => _stage == 'connected';

  @override
  void initState() {
    super.initState();
    _init();
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  Future<void> _init() async {
    await _loadServers();
    try {
      await _wg.initialize();
      _sub = _wg.stageStream.listen((event) {
        final s = event.toString().split('.').last.toLowerCase();
        if (!mounted) return;
        setState(() {
          _stage = s;
          if (s == 'connected' ||
              s == 'disconnected' ||
              s == 'denied' ||
              s == 'noconnection') {
            _busy = false;
          }
        });
      });
      _ready = true;
    } catch (e) {
      _toast('VPN ishga tushmadi: $e');
    }
    if (mounted) setState(() {});
  }

  Future<void> _loadServers() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('servers');
    if (raw == null) {
      defaultConfigs.forEach((name, conf) {
        if (VpnServer.isValid(conf)) _servers.add(VpnServer(name, conf));
      });
      await _save();
    } else {
      final list = jsonDecode(raw) as List;
      _servers.addAll(
          list.map((e) => VpnServer.fromJson(Map<String, dynamic>.from(e))));
    }
    _selected = (prefs.getInt('selected') ?? 0);
    if (_selected >= _servers.length) _selected = 0;
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        'servers', jsonEncode(_servers.map((e) => e.toJson()).toList()));
    await prefs.setInt('selected', _selected);
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _toggle() async {
    if (_busy || !_ready) return;
    if (_connected) {
      setState(() => _busy = true);
      try {
        await _wg.stop();
      } catch (e) {
        _toast('Uzishda xato: $e');
        setState(() => _busy = false);
      }
      return;
    }
    if (_servers.isEmpty) {
      _toast('Avval .conf faylini qo\'shing');
      return;
    }
    final s = _servers[_selected];
    setState(() => _busy = true);
    try {
      await _wg.start(s.endpoint, s.conf);
    } catch (e) {
      _toast('Ulanishda xato: $e');
      setState(() => _busy = false);
    }
  }

  Future<void> _importFiles() async {
    final res = await FilePicker.platform
        .pickFiles(type: FileType.any, allowMultiple: true, withData: true);
    if (res == null) return;
    var added = 0;
    for (final f in res.files) {
      final bytes = f.bytes;
      if (bytes == null) continue;
      final text = utf8.decode(bytes, allowMalformed: true);
      if (!VpnServer.isValid(text)) continue;
      final name = f.name.replaceAll(RegExp(r'\.conf$', caseSensitive: false), '');
      _servers.add(VpnServer(name, text));
      added++;
    }
    await _save();
    if (mounted) setState(() {});
    _toast(added > 0 ? '$added ta server qo\'shildi' : 'To\'g\'ri .conf topilmadi');
  }

  Future<void> _pasteConf() async {
    final nameCtl = TextEditingController();
    final confCtl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('.conf matnini qo\'yish'),
        content: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(
                controller: nameCtl,
                decoration: const InputDecoration(labelText: 'Nomi')),
            TextField(
                controller: confCtl,
                maxLines: 8,
                decoration: const InputDecoration(labelText: '[Interface] ... [Peer] ...')),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Bekor')),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Qo\'shish')),
        ],
      ),
    );
    if (ok != true) return;
    if (!VpnServer.isValid(confCtl.text)) {
      _toast('.conf noto\'g\'ri (Interface, Peer, Endpoint kerak)');
      return;
    }
    final name = nameCtl.text.trim().isEmpty ? 'Server ${_servers.length + 1}' : nameCtl.text.trim();
    _servers.add(VpnServer(name, confCtl.text));
    await _save();
    if (mounted) setState(() {});
  }

  Future<void> _delete(int i) async {
    _servers.removeAt(i);
    if (_selected >= _servers.length) _selected = 0;
    await _save();
    if (mounted) setState(() {});
  }

  String get _statusText {
    if (_busy && !_connected) return 'Ulanmoqda...';
    switch (_stage) {
      case 'connected':
        return 'Ulangan';
      case 'denied':
        return 'Ruxsat berilmadi';
      case 'connecting':
        return 'Ulanmoqda...';
      case 'disconnecting':
        return 'Uzilmoqda...';
      default:
        return 'Ulanmagan';
    }
  }

  @override
  Widget build(BuildContext context) {
    final green = Theme.of(context).colorScheme.primary;
    return Scaffold(
      appBar: AppBar(
        title: const Text('KNOWME VPN'),
        actions: [
          IconButton(
              tooltip: '.conf import',
              onPressed: _importFiles,
              icon: const Icon(Icons.file_open)),
          IconButton(
              tooltip: 'Matn qo\'yish',
              onPressed: _pasteConf,
              icon: const Icon(Icons.paste)),
        ],
      ),
      body: Column(children: [
        const SizedBox(height: 32),
        GestureDetector(
          onTap: _toggle,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            width: 150,
            height: 150,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _connected ? green : Colors.transparent,
              border: Border.all(color: green, width: 4),
            ),
            child: _busy && !_connected
                ? const Center(child: CircularProgressIndicator())
                : Icon(Icons.power_settings_new,
                    size: 72, color: _connected ? Colors.black : green),
          ),
        ),
        const SizedBox(height: 16),
        Text(_statusText, style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 24),
        const Align(
          alignment: Alignment.centerLeft,
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Text('SELECT SERVER'),
          ),
        ),
        Expanded(
          child: _servers.isEmpty
              ? const Center(child: Text('Server yo\'q. Yuqoridan .conf qo\'shing.'))
              : ListView.builder(
                  itemCount: _servers.length,
                  itemBuilder: (c, i) {
                    final s = _servers[i];
                    return ListTile(
                      leading: Icon(
                          i == _selected
                              ? Icons.radio_button_checked
                              : Icons.radio_button_off,
                          color: green),
                      title: Text(s.name),
                      subtitle: Text(s.endpoint),
                      onTap: _connected || _busy
                          ? null
                          : () {
                              setState(() => _selected = i);
                              _save();
                            },
                      trailing: IconButton(
                          icon: const Icon(Icons.delete_outline),
                          onPressed: _connected || _busy ? null : () => _delete(i)),
                    );
                  }),
        ),
      ]),
    );
  }
}
