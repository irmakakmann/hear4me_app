import 'package:flutter_test/flutter_test.dart';
import 'package:hear4me_protosound/hear4me_protosound.dart';
import 'package:hear4me_protosound/hear4me_protosound_platform_interface.dart';
import 'package:hear4me_protosound/hear4me_protosound_method_channel.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class MockHear4meProtosoundPlatform
    with MockPlatformInterfaceMixin
    implements Hear4meProtosoundPlatform {

  @override
  Future<String?> getPlatformVersion() => Future.value('42');
}

void main() {
  final Hear4meProtosoundPlatform initialPlatform = Hear4meProtosoundPlatform.instance;

  test('$MethodChannelHear4meProtosound is the default instance', () {
    expect(initialPlatform, isInstanceOf<MethodChannelHear4meProtosound>());
  });

  test('getPlatformVersion', () async {
    Hear4meProtosound hear4meProtosoundPlugin = Hear4meProtosound();
    MockHear4meProtosoundPlatform fakePlatform = MockHear4meProtosoundPlatform();
    Hear4meProtosoundPlatform.instance = fakePlatform;

    expect(await hear4meProtosoundPlugin.getPlatformVersion(), '42');
  });
}
