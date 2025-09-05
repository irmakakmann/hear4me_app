import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';

import 'audio_classifier.dart'; // make sure this file exists from earlier steps

// Service UUID from your ESP32 firmware (the "UART service")
final serviceUuid = Uuid.parse("6E400001-B5A3-F393-E0A9-E50E24DCCA9E");

// The characteristic you SUBSCRIBE to (watch → phone)
final txCharUuid  = Uuid.parse("6E400003-B5A3-F393-E0A9-E50E24DCCA9E"); // TX

// The characteristic you WRITE to (phone → watch)
final rxCharUuid  = Uuid.parse("6E400002-B5A3-F393-E0A9-E50E24DCCA9E"); // RX


final ble = FlutterReactiveBle();

void main() {
  runApp(MaterialApp(
    debugShowCheckedModeBanner: false,
    home: BleTfliteDemo(),
  ));
}

class BleTfliteDemo extends StatefulWidget {
  const BleTfliteDemo({super.key});
  @override
  State<BleTfliteDemo> createState() => _BleTfliteDemoState();
}

class _BleTfliteDemoState extends State<BleTfliteDemo> {
  DiscoveredDevice? _device;
  QualifiedCharacteristic? _ch;

  // 1-second PCM16 buffer @16 kHz
  final List<int> _pcm = <int>[];
  static const int sr = 16000;
  static const int win = sr * 1; // 1s

  String status = 'idle';
  String label = '-';
  double score = 0.0;

  late final AudioClassifier classifier;

  @override
  void initState() {
    super.initState();
    classifier = AudioClassifier();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    setState(() => status = 'requesting permissions…');
    await Permission.bluetooth.request();
    await Permission.bluetoothScan.request();
    await Permission.bluetoothConnect.request();
    await Permission.location.request(); // needed on some Androids for BLE scan

    setState(() => status = 'loading tflite model…');
    await classifier.load(); // loads assets/model.tflite

    setState(() => status = 'scanning…');
    ble.scanForDevices(withServices: [serviceUuid]).listen((d) async {
      // Optionally filter: if (d.name != 'TTGO_AUDIO') return;
      if (_device != null) return;
      _device = d;
      setState(() => status = 'connecting…');
      ble.connectToDevice(id: d.id).listen((cs) {
        if (cs.connectionState == DeviceConnectionState.connected) {
          _subscribe(d.id);
        }
      });
    });
  }

  void _subscribe(String deviceId) {
    _ch = QualifiedCharacteristic(
      serviceId: serviceUuid,
      characteristicId: txCharUuid,
      deviceId: deviceId,
    );
    setState(() => status = 'subscribed, streaming…');

    // flutter_reactive_ble provides Stream<List<int>>
    ble.subscribeToCharacteristic(_ch!).listen((List<int> data) {
      // Convert to ByteData for int16 LE parsing
      final bd = ByteData.sublistView(Uint8List.fromList(data));
      for (int i = 0; i < bd.lengthInBytes; i += 2) {
        _pcm.add(bd.getInt16(i, Endian.little));
      }

      // 1s window with 50% overlap
      if (_pcm.length >= win) {
        final frame = _pcm.sublist(0, win);
        _processFrame(frame);
        _pcm.removeRange(0, win ~/ 2);
      }
    });
  }

  void _processFrame(List<int> frame) {
    final res = classifier.infer(frame); // {label, score, probs, index}
    final lbl = res['label'] as String;
    final sc = (res['score'] as double);

    setState(() {
      label = lbl;
      score = sc;
      status = sc > 0.65 ? 'DETECTED' : 'running';
    });

    // Example: print JSON for debugging
    // ignore: avoid_print
    print(jsonEncode({'label': lbl, 'score': sc}));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('BLE + TFLite (1s audio)')),
      body: Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text('Status: $status'),
          const SizedBox(height: 8),
          Text('Label: $label', style: const TextStyle(fontSize: 18)),
          Text('Score: ${score.toStringAsFixed(2)}'),
          const SizedBox(height: 16),
          const Text('Ensure TTGO streams PCM16 @16kHz to the given UUIDs'),
        ]),
      ),
    );
  }
}
