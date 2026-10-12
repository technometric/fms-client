import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

void main() => runApp(const TrackingApp());

class TrackingApp extends StatelessWidget {
  const TrackingApp({super.key});

  @override
  Widget build(BuildContext c) => MaterialApp(
    debugShowCheckedModeBanner: false,
    title: 'Tracking Mobile',
    theme: ThemeData(colorSchemeSeed: Colors.blue, useMaterial3: true),
    home: const TrackingPage(),
  );
}

class TrackingPage extends StatefulWidget {
  const TrackingPage({super.key});

  @override
  State<TrackingPage> createState() => _TrackingPageState();
}

class _TrackingPageState extends State<TrackingPage> {
  final server = TextEditingController();
  final port = TextEditingController(text: '5055');
  final device = TextEditingController();
  final interval = TextEditingController(text: '15');

  Timer? timer;
  String status = 'Berhenti';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final p = await SharedPreferences.getInstance();

    server.text = p.getString('server') ?? '';
    device.text = p.getString('device') ?? '';
    interval.text = p.getString('interval') ?? '15';
  }

  Future<void> _start() async {
    if (server.text.trim().isEmpty || device.text.trim().isEmpty) {
      setState(() => status = 'Server dan Device ID wajib diisi');
      return;
    }

    setState(() => status = 'Meminta izin lokasi...');

    var permission = await Geolocator.checkPermission();

    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      setState(() => status = 'Izin lokasi ditolak');
      return;
    }

    final p = await SharedPreferences.getInstance();

    await p.setString('server', server.text);
    await p.setString('device', device.text);
    await p.setString('interval', interval.text);

    timer?.cancel();

    final seconds = int.tryParse(interval.text) ?? 15;

    setState(() => status = 'Tracking aktif');
    _send();

    timer = Timer.periodic(
      Duration(seconds: seconds.clamp(5, 3600)),
      (_) => _send(),
    );
  }

  Future<void> _send() async {
    try {
      if (mounted) {
        setState(() => status = 'Mengambil lokasi...');
      }

      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );

      final uri = Uri(
        scheme: 'http',
        host: server.text.trim(),
        port: int.tryParse(port.text) ?? 5055,
        path: '/',
        queryParameters: {
          'id': device.text.trim(),
          'lat': '${pos.latitude}',
          'lon': '${pos.longitude}',
          'speed': '${pos.speed * 3.6}',
          'accuracy': '${pos.accuracy}',
          'timestamp':
              '${DateTime.now().millisecondsSinceEpoch ~/ 1000}',
        },
      );

      if (mounted) {
        setState(() => status = 'Mengirim ke server...');
      }

      final response = await http
          .get(uri)
          .timeout(const Duration(seconds: 10));

      if (mounted) {
        setState(
          () => status =
              'Terkirim (${response.statusCode}) '
              '${pos.latitude.toStringAsFixed(5)}, '
              '${pos.longitude.toStringAsFixed(5)}',
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => status = 'Gagal mengirim: $e');
      }
    }
  }

  void _stop() {
    timer?.cancel();
    setState(() => status = 'Berhenti');
  }

  @override
  void dispose() {
    timer?.cancel();
    server.dispose();
    port.dispose();
    device.dispose();
    interval.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext c) => Scaffold(
    appBar: AppBar(title: const Text('Tracking Mobile')),
    body: ListView(
      padding: const EdgeInsets.all(20),
      children: [
        TextField(
          controller: server,
          decoration: const InputDecoration(
            labelText: 'Server / IP publik',
            hintText: 'contoh: 192.168.1.10',
          ),
        ),
        TextField(
          controller: port,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'Port'),
        ),
        TextField(
          controller: device,
          decoration: const InputDecoration(labelText: 'Device ID / Unique ID'),
        ),
        TextField(
          controller: interval,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'Interval (detik)'),
        ),
        const SizedBox(height: 20),
        Row(
          children: [
            Expanded(
              child: FilledButton(
                onPressed: _start,
                child: const Text('Mulai tracking'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: OutlinedButton(
                onPressed: _stop,
                child: const Text('Stop'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        Text('Status: $status'),
      ],
    ),
  );
}
