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
  final mono = Uint8List.fromList([4, 5, 6]);
  late bool contactsAllowed;
  late bool calendarAllowed;
  late bool notificationsAllowed;
  late List<Map<String, Object?>> posted;
  Map<String, Object?>? playing;
  late String privateSpace;

  setUp(() {
    installed = [
      {'id': 'com.a/.Main', 'label': 'Alpha'},
      {'id': 'com.b/.Main', 'label': 'Beta', 'canUninstall': false},
      {'id': 'com.w/.Main#10', 'label': 'Work mail', 'work': true},
    ];
    prefs = {};
    defaults = ['com.b/.Main'];
    contactsAllowed = false;
    calendarAllowed = false;
    notificationsAllowed = false;
    posted = [];
    playing = null;
    privateSpace = 'none';
    calls = [];
    messenger.setMockMethodCallHandler(methods, (call) async {
      calls.add(call);
      return switch (call.method) {
        'apps' => installed,
        'icons' => {
          for (final id in (call.arguments as Map)['ids'] as List)
            id: {'icon': icon, if (id == 'com.a/.Main') 'mono': mono},
        },
        'launch' => (call.arguments as Map)['id'] == 'com.a/.Main',
        'battery' => {'level': 0.82, 'charging': false},
        'isDefaultHome' => false,
        'requestDefaultHome' => null,
        'defaultApps' => defaults,
        'roles' => {'messages': 'com.b/.Main'},
        'getPref' => prefs[(call.arguments as Map)['key']],
        'setPref' =>
          prefs[(call.arguments as Map)['key'] as String] =
              (call.arguments as Map)['value'] as String,
        'shortcuts' => [
          {'id': 's1', 'label': 'New message'},
        ],
        'startShortcut' => true,
        'appInfo' || 'uninstall' || 'openSettings' || 'openContact' => null,
        'requestContacts' => null,
        'canSearchContacts' => contactsAllowed,
        'searchContacts' => [
          {'id': 'k/1', 'name': 'Mira Okafor'},
        ],
        'privateSpace' => privateSpace,
        'setPrivateSpaceLocked' => null,
        'openAssistant' => true,
        'canReadCalendar' => calendarAllowed,
        'agenda' => [
          {
            'start': DateTime(2026, 10, 26, 9).millisecondsSinceEpoch,
            'title': 'Standup',
            'location': 'Room 3',
            'attendees': 4,
          },
          {
            'start': DateTime(2099, 1, 1, 9).millisecondsSinceEpoch,
            'title': 'Later',
            'location': '',
            'attendees': null,
          },
        ],
        'canReadNotifications' => notificationsAllowed,
        'notifications' => posted,
        'media' => playing,
        'requestCalendar' ||
        'requestNotificationAccess' ||
        'dismissNotification' ||
        'snoozeNotification' ||
        'setPlaying' => null,
        'openNotification' => true,
        'replyNotification' => (call.arguments as Map)['text'] != '',
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
    final byId = {for (final a in b.apps) a.id: a};
    expect(byId['com.a/.Main']!.monoIcon, mono);
    expect(byId['com.b/.Main']!.monoIcon, isNull);
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

  group('search sources', () {
    test('contacts: nothing without the permission, results with it', () async {
      final b = await AndroidBackend.create();
      addTearDown(b.dispose);
      expect(b.canSearchContacts, isFalse);
      expect(await b.searchContacts('mi'), isEmpty);
      expect(calls.where((c) => c.method == 'searchContacts'), isEmpty);

      contactsAllowed = true;
      final changed = expectLater(b.changes, emits(null));
      sink.success({'type': 'contacts'});
      await changed;
      expect(b.canSearchContacts, isTrue);
      final found = await b.searchContacts('mi');
      expect(found.single.name, 'Mira Okafor');
      expect(found.single.initials, 'MO');
      await b.openContact(found.single.id);
      expect(calls.last.arguments, {'id': 'k/1'});
    });

    test('settings pages are the shared list and open by id', () async {
      final b = await AndroidBackend.create();
      addTearDown(b.dispose);
      expect(b.settingsPages, defaultSettingsPages);
      await b.openSettingsPage('wifi');
      expect(calls.last.method, 'openSettings');
      expect(calls.last.arguments, {'id': 'wifi'});
    });
  });

  group('private space', () {
    test('state comes from the platform', () async {
      privateSpace = 'locked';
      final b = await AndroidBackend.create();
      addTearDown(b.dispose);
      expect(b.privateSpace, PrivateSpaceState.locked);
      privateSpace = 'unlocked';
      installed.add({
        'id': 'com.bank/.Main#11',
        'label': 'Bank',
        'privateSpace': true,
      });
      sink.success({'type': 'apps'});
      await settle();
      await settle();
      expect(b.privateSpace, PrivateSpaceState.unlocked);
      expect(b.apps.firstWhere((a) => a.label == 'Bank').privateSpace, isTrue);
    });

    test('an unknown answer means none', () async {
      privateSpace = 'weird';
      final b = await AndroidBackend.create();
      addTearDown(b.dispose);
      expect(b.privateSpace, PrivateSpaceState.none);
    });

    test('lock and unlock go to the platform', () async {
      final b = await AndroidBackend.create();
      addTearDown(b.dispose);
      await b.setPrivateSpaceLocked(false);
      expect(calls.last.method, 'setPrivateSpaceLocked');
      expect(calls.last.arguments, {'locked': false});
    });
  });

  test('the default app for a design role gets its glyph', () async {
    final b = await AndroidBackend.create();
    addTearDown(b.dispose);
    final byId = {for (final a in b.apps) a.id: a};
    expect(byId['com.b/.Main']!.glyph, 'messages');
    expect(byId['com.a/.Main']!.glyph, isNull);
    await settle();
    // Icons keep the glyph.
    expect(b.apps.firstWhere((a) => a.id == 'com.b/.Main').glyph, 'messages');
  });

  test('the system assistant goes to the platform', () async {
    final b = await AndroidBackend.create();
    addTearDown(b.dispose);
    expect(await b.openAssistant(), isTrue);
    expect(calls.last.method, 'openAssistant');
  });

  group('calendar', () {
    test('nothing without the permission', () async {
      final b = await AndroidBackend.create();
      addTearDown(b.dispose);
      expect(b.canReadCalendar, isFalse);
      expect(b.agenda, isEmpty);
      expect(calls.where((c) => c.method == 'agenda'), isEmpty);
    });

    test('today\'s events, and the next one', () async {
      calendarAllowed = true;
      final b = await AndroidBackend.create();
      addTearDown(b.dispose);
      expect(b.agenda.map((e) => e.title), ['Standup', 'Later']);
      expect(b.agenda.first.attendees, 4);
      expect(b.agenda.first.location, 'Room 3');
      expect(b.nextEvent?.title, 'Later');
    });

    test('a calendar change reloads', () async {
      final b = await AndroidBackend.create();
      addTearDown(b.dispose);
      calendarAllowed = true;
      final changed = expectLater(b.changes, emits(null));
      sink.success({'type': 'calendar'});
      await changed;
      expect(b.agenda, hasLength(2));
    });
  });

  group('notifications', () {
    Map<String, Object?> post(
      String id, {
      required int at,
      String title = 'Elif',
      String app = 'Messages',
      String package = 'com.a',
      bool canReply = false,
    }) => {
      'id': id,
      'package': package,
      'app': app,
      'title': title,
      'text': 'Are we still on for 7?',
      'postTime': at,
      'canReply': canReply,
      'canDismiss': true,
    };

    test('nothing without access', () async {
      posted = [post('k1', at: 10)];
      final b = await AndroidBackend.create();
      addTearDown(b.dispose);
      expect(b.canReadNotifications, isFalse);
      expect(b.notifications, isEmpty);
    });

    test('unread since Stream was last seen; marks by the rules', () async {
      notificationsAllowed = true;
      prefs['streamSeen'] = '100';
      posted = [
        post('new-msg', at: 300, canReply: true),
        post(
          'new-other',
          at: 200,
          title: 'Parcel',
          app: 'Parcel',
          package: 'p',
        ),
        post('old', at: 50, title: 'Deniz', canReply: true),
      ];
      final b = await AndroidBackend.create();
      addTearDown(b.dispose);
      final byId = {for (final n in b.notifications) n.id: n};
      expect(byId['new-msg']!.mark, StreamMark.current);
      expect(byId['new-other']!.mark, StreamMark.alert);
      expect(byId['old']!.mark, StreamMark.read);
      expect(byId['new-msg']!.source, 'Messages · Elif');
      expect(byId['new-msg']!.sender, 'Elif');
      // Its app on the arc, for the unread badge.
      expect(byId['new-msg']!.app, 'com.a/.Main');
      expect(b.streamSummary.newCount, 2);
      expect(b.streamSummary.needYou, ['Reply to Elif']);
      expect(b.notifications.map((n) => n.id).last, 'old');
    });

    test('leaving Stream marks them seen, and that is saved', () async {
      notificationsAllowed = true;
      posted = [post('k1', at: 300, canReply: true)];
      final b = await AndroidBackend.create();
      addTearDown(b.dispose);
      expect(b.notifications.single.unread, isTrue);
      b.markNotificationsSeen();
      expect(b.notifications.single.unread, isFalse);
      await settle();
      expect(prefs['streamSeen'], '300');
    });

    test('actions go to the platform by id', () async {
      notificationsAllowed = true;
      posted = [post('k1', at: 300, canReply: true)];
      final b = await AndroidBackend.create();
      addTearDown(b.dispose);
      expect(await b.replyToNotification('k1', 'Yes'), isTrue);
      expect(calls.last.arguments, {'id': 'k1', 'text': 'Yes'});
      await b.openNotification('k1');
      await b.dismissNotification('k1');
      await b.snoozeNotification('k1');
      expect(calls.map((c) => c.method).toList().sublist(calls.length - 3), [
        'openNotification',
        'dismissNotification',
        'snoozeNotification',
      ]);
    });

    test('a posted notification reloads', () async {
      notificationsAllowed = true;
      final b = await AndroidBackend.create();
      addTearDown(b.dispose);
      posted = [post('k1', at: 300)];
      final changed = expectLater(b.changes, emits(null));
      sink.success({'type': 'notifications'});
      await changed;
      expect(b.notifications, hasLength(1));
    });
  });

  group('media', () {
    test('the playing session is the media strip; play and pause', () async {
      playing = {
        'title': 'Night Drive',
        'artist': 'Mira Okafor',
        'progress': 0.4,
        'playing': true,
      };
      final b = await AndroidBackend.create();
      addTearDown(b.dispose);
      expect(b.quick.media?.title, 'Night Drive');
      expect(b.quick.media?.playing, isTrue);
      b.setPlaying(false);
      expect(b.quick.media?.playing, isFalse);
      expect(calls.last.arguments, {'playing': false});
    });

    test('no session, no strip', () async {
      final b = await AndroidBackend.create();
      addTearDown(b.dispose);
      expect(b.quick.media, isNull);
    });
  });
}
