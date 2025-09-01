import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:hear4me_protosound/hear4me_protosound.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: ProtoSoundTestPage(),
    );
  }
}

class ProtoSoundTestPage extends StatefulWidget {
  const ProtoSoundTestPage({super.key});
  @override
  State<ProtoSoundTestPage> createState() => _ProtoSoundTestPageState();
}

class _ProtoSoundTestPageState extends State<ProtoSoundTestPage> {
  String status = 'idle';

  Future<void> _init() async {
    setState(() => status = 'requesting mic…');
    await Permission.microphone.request();

    setState(() => status = 'loading model…');
    try {
      await Hear4MeProtoSound.initialize(modelAsset: 'protosound_model.ptl');
      setState(() => status = '✅ model loaded');
    } catch (e) {
      setState(() => status = '❌ init failed: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('ProtoSound test')),
      body: Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(status),
          const SizedBox(height: 12),
          ElevatedButton(onPressed: _init, child: const Text('Initialize ProtoSound')),
        ]),
      ),
    );
  }
}
