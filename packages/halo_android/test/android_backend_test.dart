import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:halo_android/halo_android.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const methods = MethodChannel('halo_android');
  const events = EventChannel('halo_android/events');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  late List<Map<String, String>> installed;
  late List<MethodCall> calls;
  late MockStreamHandlerEventSink sink;
  final icon = Uint8List.fromList([1, 2, 3]);

  setUp(() {
    installed = [
      {'id': 'com.a/.Main', 'label': 'Alpha'},
      {'id': 'com.b/.Main', 'label': 'Beta'},
    ];
    calls = [];
    messenger.setMockMethodCallHandler(methods, (call) async {
      calls.add(call);
      return switch (call.method) {
        'apps' => installed,
        'icons' => {
          for (final id in (call.arguments as Map)['ids'] as List) id: icon,
        },
        'launch' => (call.arguments as Map)['id'] == 'com.a/.Main',
        'battery' => {'level': 0.82, 'charging': false},
        'isDefaultHome' => false,
        'requestDefaultHome' => null,
        _ => throw MissingPluginException(),
      };
    });
    messenger.setMockStreamHandler(
      events,
      MockStreamHandler.inline(onListen: (_, s) => sink = s),
    );
  });

  tearDown(() {
    messenger.setMockMethodCallHandler(methods, null);
    messenger.setMockStreamHandler(events, null);
  });

  Future<void> settle() => Future<void>.delayed(Duration.zero);

  test('loads apps, battery and the default home state up front', () async {
    final b = await AndroidBackend.create();
    addTearDown(b.dispose);
    expect(b.apps.map((a) => a.label), ['Alpha', 'Beta']);
    expect(b.status.batteryPercent, 82);
    expect(b.status.network, isEmpty);
    expect(b.isDefaultHome, isFalse);
  });

  test('icons arrive after the list and notify', () async {
    final b = await AndroidBackend.create();
    addTearDown(b.dispose);
    final changed = b.changes.first;
    await changed;
    for (final a in b.apps) {
      expect(a.icon, icon);
    }
    final req = calls.firstWhere((c) => c.method == 'icons');
    expect((req.arguments as Map)['size'], AndroidBackend.iconSize);
  });

  test(
    'a package change reloads the list and only fetches new icons',
    () async {
      final b = await AndroidBackend.create();
      addTearDown(b.dispose);
      await settle();
      installed.add({'id': 'com.c/.Main', 'label': 'Gamma'});
      calls.clear();
      sink.success({'type': 'apps'});
      await settle();
      await settle();
      expect(b.apps.map((a) => a.label), ['Alpha', 'Beta', 'Gamma']);
      final req = calls.firstWhere((c) => c.method == 'icons');
      expect((req.arguments as Map)['ids'], ['com.c/.Main']);
    },
  );

  test('launch reports what the platform says', () async {
    final b = await AndroidBackend.create();
    addTearDown(b.dispose);
    expect(await b.launch('com.a/.Main'), isTrue);
    expect(await b.launch('com.gone/.Main'), isFalse);
  });

  test('Home presses come through homePressed', () async {
    final b = await AndroidBackend.create();
    addTearDown(b.dispose);
    final pressed = expectLater(b.homePressed, emits(null));
    sink.success({'type': 'home'});
    await pressed;
  });

  test('what Phase 1 does not serve is empty, not invented', () async {
    final b = await AndroidBackend.create();
    addTearDown(b.dispose);
    expect(b.agenda, isEmpty);
    expect(b.nextEvent, isNull);
    expect(b.notifications, isEmpty);
    expect(b.lockPreviews, isEmpty);
    expect(b.recents, isEmpty);
    expect(b.quick.toggles, isEmpty);
    expect(b.quick.media, isNull);
    expect(b.streamSummary.newCount, 0);
  });
}
