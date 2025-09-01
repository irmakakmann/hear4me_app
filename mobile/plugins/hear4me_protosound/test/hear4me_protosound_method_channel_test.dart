import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hear4me_protosound/hear4me_protosound_method_channel.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  MethodChannelHear4meProtosound platform = MethodChannelHear4meProtosound();
  const MethodChannel channel = MethodChannel('hear4me_protosound');

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      channel,
      (MethodCall methodCall) async {
        return '42';
      },
    );
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel, null);
  });

  test('getPlatformVersion', () async {
    expect(await platform.getPlatformVersion(), '42');
  });
}
