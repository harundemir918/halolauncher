import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:halo_android/halo_android.dart';
import 'package:halo_sdk/halo_sdk.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const methods = MethodChannel('halo_android');
  const events = EventChannel('halo_android/events');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  late List<Map<String, Object>> installed;
  late Map<String, String> prefs;
  late List<String> defaults;
  late List<MethodCall> calls;
  late MockStreamHandlerEventSink sink;
  final icon = Uint8List.fromList([1, 2, 3]);

  setUp(() {
    installed = [
      {'id': 'com.a/.Main', 'label': 'Alpha'},
      {'id': 'com.b/.Main', 'label': 'Beta', 'canUninstall': false},
      {'id': 'com.w/.Main#10', 'label': 'Work mail', 'work': true},
    ];
    prefs = {};
    defaults = ['com.b/.Main'];
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
        'defaultApps' => defaults,
        'getPref' => prefs[(call.arguments as Map)['key']],
        'setPref' =>
          prefs[(call.arguments as Map)['key'] as String] =
              (call.arguments as Map)['value'] as String,
        'shortcuts' => [
          {'id': 's1', 'label': 'New message'},
        ],
        'startShortcut' => true,
        'appInfo' || 'uninstall' => null,
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
    expect(b.apps.map((a) => a.label), ['Alpha', 'Beta', 'Work mail']);
    expect(b.status.batteryPercent, 82);
    expect(b.status.network, isEmpty);
    expect(b.isDefaultHome, isFalse);
  });

  test('icons arrive after the list', () async {
    final b = await AndroidBackend.create();
    addTearDown(b.dispose);
    // Icons are fetched in the background; by the time the queued work has
    // run, every app has one.
    await settle();
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
      expect(b.apps.map((a) => a.label), [
        'Alpha',
        'Beta',
        'Work mail',
        'Gamma',
      ]);
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

  test('maps the work profile and uninstall flags', () async {
    final b = await AndroidBackend.create();
    addTearDown(b.dispose);
    final byLabel = {for (final a in b.apps) a.label: a};
    expect(byLabel['Work mail']!.work, isTrue);
    expect(byLabel['Alpha']!.work, isFalse);
    expect(byLabel['Beta']!.canUninstall, isFalse);
    expect(byLabel['Alpha']!.canUninstall, isTrue);
  });

  group('arc', () {
    List<String> arcIds(AndroidBackend b) => [for (final a in b.arcApps) a.id];
    List<String> saved() => (jsonDecode(prefs['arc']!) as List).cast<String>();

    test('the first time it holds the default apps, and is saved', () async {
      final b = await AndroidBackend.create();
      addTearDown(b.dispose);
      expect(arcIds(b), ['com.b/.Main']);
      expect(saved(), ['com.b/.Main']);
    });

    test('with no default apps it takes the first apps', () async {
      defaults = [];
      final b = await AndroidBackend.create();
      addTearDown(b.dispose);
      expect(arcIds(b), ['com.a/.Main', 'com.b/.Main', 'com.w/.Main#10']);
    });

    test('a saved arc wins, and apps that are gone are not shown', () async {
      prefs['arc'] = jsonEncode(['com.gone/.Main', 'com.a/.Main']);
      final b = await AndroidBackend.create();
      addTearDown(b.dispose);
      expect(arcIds(b), ['com.a/.Main']);
    });

    test('pin, move and unpin are saved', () async {
      final b = await AndroidBackend.create();
      addTearDown(b.dispose);
      b.pinToArc('com.a/.Main');
      expect(arcIds(b), ['com.b/.Main', 'com.a/.Main']);
      b.moveOnArc('com.a/.Main', -1);
      expect(arcIds(b), ['com.a/.Main', 'com.b/.Main']);
      b.unpinFromArc('com.b/.Main');
      await settle();
      expect(saved(), ['com.a/.Main']);
    });

    test('moving steps over apps that are gone', () async {
      prefs['arc'] = jsonEncode([
        'com.a/.Main',
        'com.gone/.Main',
        'com.b/.Main',
      ]);
      final b = await AndroidBackend.create();
      addTearDown(b.dispose);
      b.moveOnArc('com.b/.Main', -1);
      expect(arcIds(b), ['com.b/.Main', 'com.a/.Main']);
      await settle();
      expect(saved(), contains('com.gone/.Main'));
    });

    test('pinning an unknown or pinned app does nothing', () async {
      final b = await AndroidBackend.create();
      addTearDown(b.dispose);
      b
        ..pinToArc('com.nope/.Main')
        ..pinToArc('com.b/.Main');
      expect(arcIds(b), ['com.b/.Main']);
    });
  });

  test('appearance and text size are loaded and saved', () async {
    prefs['appearance'] = 'light';
    prefs['textSize'] = '0.75';
    final b = await AndroidBackend.create();
    addTearDown(b.dispose);
    expect(b.system.appearance, Appearance.light);
    expect(b.system.textSize, 0.75);
    b
      ..setAppearance(Appearance.dark)
      ..setTextSize(0.25);
    await settle();
    expect(prefs['appearance'], 'dark');
    expect(prefs['textSize'], '0.25');
  });

  test('shortcuts, App info and uninstall go to the platform', () async {
    final b = await AndroidBackend.create();
    addTearDown(b.dispose);
    expect((await b.shortcuts('com.a/.Main')).single.label, 'New message');
    expect(await b.startShortcut('com.a/.Main', 's1'), isTrue);
    await b.openAppInfo('com.a/.Main');
    await b.uninstall('com.w/.Main#10');
    final sent = {
      for (final c in calls)
        if (c.method == 'appInfo' || c.method == 'uninstall')
          c.method: (c.arguments as Map)['id'],
    };
    expect(sent, {'appInfo': 'com.a/.Main', 'uninstall': 'com.w/.Main#10'});
  });
}
