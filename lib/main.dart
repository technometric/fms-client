import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

const appVersion = '0.1.0+1';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeService();
  runApp(const TrackingApp());
}

Future<void> initializeService() async {
  final service = FlutterBackgroundService();

  await service.configure(
    androidConfiguration: AndroidConfiguration(
      onStart: onServiceStart,
      autoStart: false,
      autoStartOnBoot: false,
      isForegroundMode: true,
      foregroundServiceTypes: [AndroidForegroundType.location],
      initialNotificationTitle: 'Tracking aktif',
      initialNotificationContent: 'Menyiapkan pengiriman lokasi',
      foregroundServiceNotificationId: 888,
    ),
    iosConfiguration: IosConfiguration(
      autoStart: false,
      onForeground: onServiceStart,
    ),
  );
}

@pragma('vm:entry-point')
void onServiceStart(ServiceInstance service) async {
  DartPluginRegistrant.ensureInitialized();

  Timer? timer;

  Future<void> sendLocation() async {
    try {
      final p = await SharedPreferences.getInstance();
      final server = p.getString('server') ?? '';
      final port = int.tryParse(p.getString('port') ?? '') ?? 5055;
      final device = p.getString('device') ?? '';

      if (server.isEmpty || device.isEmpty) {
        service.invoke('status', {
          'message': 'Server dan Device ID wajib diisi',
        });
        return;
      }

      service.invoke('status', {'message': 'Mengambil lokasi...'});

      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );

      final uri = Uri(
        scheme: 'http',
        host: server,
        port: port,
        path: '/',
        queryParameters: {
          'id': device,
          'lat': '${pos.latitude}',
          'lon': '${pos.longitude}',
          'speed': '${pos.speed * 3.6}',
          'accuracy': '${pos.accuracy}',
          'timestamp': '${DateTime.now().millisecondsSinceEpoch ~/ 1000}',
        },
      );

      service.invoke('status', {'message': 'Mengirim ke server...'});

      final response = await http
          .get(uri)
          .timeout(const Duration(seconds: 10));

      final message =
          'Terkirim (${response.statusCode}) '
          '${pos.latitude.toStringAsFixed(5)}, '
          '${pos.longitude.toStringAsFixed(5)}';

      service.invoke('status', {'message': message});

      if (service is AndroidServiceInstance) {
        await service.setForegroundNotificationInfo(
          title: 'Tracking aktif',
          content: message,
        );
      }
    } catch (e) {
      service.invoke('status', {'message': 'Gagal mengirim: $e'});
    }
  }

  Future<void> startTracking() async {
    final p = await SharedPreferences.getInstance();
    final seconds = (int.tryParse(p.getString('interval') ?? '') ?? 15)
        .clamp(5, 3600);

    timer?.cancel();

    if (service is AndroidServiceInstance) {
      await service.setAsForegroundService();
      await service.setForegroundNotificationInfo(
        title: 'Tracking aktif',
        content: 'Mengirim lokasi setiap $seconds detik',
      );
    }

    service.invoke('status', {'message': 'Tracking aktif'});
    await sendLocation();
    timer = Timer.periodic(Duration(seconds: seconds), (_) => sendLocation());
  }

  service.on('startTracking').listen((_) {
    startTracking();
  });

  service.on('stopTracking').listen((_) async {
    timer?.cancel();
    timer = null;
    service.invoke('status', {'message': 'Berhenti'});
    await service.stopSelf();
  });

  await startTracking();
}

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

  StreamSubscription<Map<String, dynamic>?>? statusSubscription;
  String status = 'Berhenti';

  @override
  void initState() {
    super.initState();
    _load();
    statusSubscription = FlutterBackgroundService()
        .on('status')
        .listen((event) {
      final message = event?['message']?.toString();

      if (message != null && mounted) {
        setState(() => status = message);
      }
    });
  }

  Future<void> _load() async {
    final p = await SharedPreferences.getInstance();

    server.text = p.getString('server') ?? '';
    device.text = p.getString('device') ?? '';
    port.text = p.getString('port') ?? '5055';
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
    await p.setString('port', port.text);
    await p.setString('device', device.text);
    await p.setString('interval', interval.text);

    final service = FlutterBackgroundService();
    final isRunning = await service.isRunning();

    setState(() => status = 'Tracking aktif');

    if (isRunning) {
      service.invoke('startTracking');
    } else {
      await service.startService();
    }
  }

  void _stop() {
    FlutterBackgroundService().invoke('stopTracking');
    setState(() => status = 'Berhenti');
  }

  @override
  void dispose() {
    statusSubscription?.cancel();
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
        const SizedBox(height: 12),
        Text(
          'Versi APK: $appVersion',
          style: Theme.of(c).textTheme.bodySmall,
          textAlign: TextAlign.center,
        ),
      ],
    ),
  );
}
