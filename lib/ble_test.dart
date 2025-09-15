import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';

const nusServiceUuid = Uuid.parse("6E400001-B5A3-F393-E0A9-E50E24DCCA9E");
const nusTxCharUuid  = Uuid.parse("6E400003-B5A3-F393-E0A9-E50E24DCCA9E");
const deviceName     = "ESP32_Audio"; // your advertised BLE name

class BleTestPage extends StatefulWidget {
  const BleTestPage({super.key});
  @override
  State<BleTestPage> createState() => _BleTestPageState();
}

class _BleTestPageState extends State<BleTestPage> {
  final _ble = FlutterReactiveBle();
  DiscoveredDevice? _device;
  QualifiedCharacteristic? _txChar;
  String _status = "Idle";
  List<String> _packets = [];

  @override
  void initState() {
    super.initState();
    _scanAndConnect();
  }

  void _scanAndConnect() {
    setState(() => _status = "Scanning…");
    _ble.scanForDevices(withServices: [nusServiceUuid]).listen((device) async {
      if (device.name == deviceName) {
        setState(() => _status = "Connecting…");
        _ble.connectToDevice(id: device.id).listen((conn) {
          if (conn.connectionState == DeviceConnectionState.connected) {
            setState(() => _status = "Connected");
            _txChar = QualifiedCharacteristic(
              deviceId: device.id,
              serviceId: nusServiceUuid,
              characteristicId: nusTxCharUuid,
            );
            // Subscribe to audio notifications
            _ble.subscribeToCharacteristic(_txChar!).listen((data) {
              // data is raw Uint8List (20 bytes each)
              final seq = data.length >= 2
                  ? (data[1] << 8) | data[0]
                  : -1;
              setState(() {
                _packets.insert(
                    0, "Seq $seq : ${data.sublist(2).map((b) => b.toRadixString(16).padLeft(2,'0')).join(' ')}");
                if (_packets.length > 50) _packets.removeLast();
              });
            });
          }
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("BLE Audio Test")),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("Status: $_status", style: const TextStyle(fontSize: 16)),
          const Divider(),
          Expanded(
            child: ListView(
              children: _packets
                  .map((p) => Text(p, style: const TextStyle(fontFamily: 'monospace')))
                  .toList(),
            ),
          ),
        ],
      ),
    );
  }
}
