import 'package:halo_sdk/halo_sdk.dart';
import 'package:test/test.dart';

void main() {
  final backend = MockBackend();

  test('fixtures match the designs', () {
    expect(backend.now, DateTime(2026, 10, 23, 9, 41));
    expect(backend.now.weekday, DateTime.friday);
    expect(backend.status.batteryPercent, 82);
    expect(backend.status.network, '5G · WI-FI');
  });

  test('next event is the Design review in Room 3, 19 minutes away', () {
    final e = backend.nextEvent!;
    expect(e.title, 'Design review');
    expect(e.location, 'Room 3');
    expect(e.minutesUntil(backend.now), 19);
  });

  test('agenda matches the Home design', () {
    final a = backend.agenda;
    expect(a.map((e) => e.title), [
      'Design review',
      'Lunch with Elif',
      'Dinner, corner table',
    ]);
    expect(a.map((e) => e.location), ['Room 3', 'Karaköy', 'Unconfirmed']);
    expect(a.first.walkMinutes, 2);
    expect(a.first.attendees, 4);
  });

  test('next event skips events that already started', () {
    final lunchTime = MockBackend(now: DateTime(2026, 10, 23, 12));
    expect(lunchTime.nextEvent!.title, 'Lunch with Elif');
    final late = MockBackend(now: DateTime(2026, 10, 23, 23));
    expect(late.nextEvent, isNull);
  });

  test('apps come by label', () {
    final labels = backend.apps.map((a) => a.label).toList();
    expect(labels, [...labels]..sort());
  });

  test('the arc is in the design order with Messages in the middle', () {
    final ids = backend.arcApps.map((a) => a.id).toList();
    expect(ids, [
      'notes',
      'maps',
      'music',
      'messages',
      'camera',
      'web',
      'phone',
    ]);
    expect(ids[ids.length ~/ 2], 'messages');
  });

  test('the mock cannot start apps and is already the default home', () async {
    final b = MockBackend();
    expect(await b.launch('messages'), isFalse);
    expect(b.isDefaultHome, isTrue);
    expect(b.apps.every((a) => a.icon == null), isTrue);
  });

  group('media', () {
    test('seeking moves the track and clamps', () {
      final b = MockBackend();
      b.seekMedia(0.8);
      expect(b.quick.media?.progress, 0.8);
      b.seekMedia(3);
      expect(b.quick.media?.progress, 1);
      b.seekMedia(-1);
      expect(b.quick.media?.progress, 0);
    });
  });

  group('arc', () {
    test('pinning adds to the right end once', () async {
      final b = MockBackend();
      b.unpinFromArc('web');
      final changed = expectLater(b.changes, emits(null));
      b.pinToArc('web');
      await changed;
      b.pinToArc('web');
      expect(b.arcApps.last.id, 'web');
      expect(b.arcApps.where((a) => a.id == 'web'), hasLength(1));
    });

    test('pinning at the start puts the app first, once', () {
      final b = MockBackend();
      b.unpinFromArc('web');
      b.pinToArc('web', atStart: true);
      b.pinToArc('web', atStart: true);
      expect(b.arcApps.first.id, 'web');
      expect(b.arcApps.where((a) => a.id == 'web'), hasLength(1));
    });

    test('a full arc takes no more, at either end', () {
      final b = _ManyApps();
      for (var i = 0; i < 10; i++) {
        b.pinToArc('x$i');
      }
      // The design's seven were already there.
      expect(b.arcApps, hasLength(maxArcApps));
      b.pinToArc('x10');
      b.pinToArc('x11', atStart: true);
      expect(b.arcApps, hasLength(maxArcApps));
      expect(b.arcApps.map((a) => a.id), isNot(contains('x10')));
      expect(b.arcApps.map((a) => a.id), isNot(contains('x11')));
      // Room again once one goes.
      b.unpinFromArc('x0');
      b.pinToArc('x10');
      expect(b.arcApps.last.id, 'x10');
    });

    test('pinning an unknown app does nothing', () {
      final b = MockBackend()..pinToArc('nope');
      expect(b.arcApps, hasLength(7));
    });

    test('moving clamps at the ends', () {
      final b = MockBackend()..moveOnArc('maps', -5);
      expect(b.arcApps.first.id, 'maps');
      b.moveOnArc('maps', 2);
      expect(b.arcApps.map((a) => a.id).take(3), ['notes', 'music', 'maps']);
      b.moveOnArc('phone', 1);
      expect(b.arcApps.last.id, 'phone');
    });

    test('unpinning removes it from the arc, not from apps', () {
      final b = MockBackend()..unpinFromArc('camera');
      expect(b.arcApps.any((a) => a.id == 'camera'), isFalse);
      expect(b.apps.any((a) => a.id == 'camera'), isTrue);
    });
  });

  test('Messages has shortcuts, App info and uninstall are recorded', () async {
    final b = MockBackend();
    expect((await b.shortcuts('messages')).map((s) => s.label), [
      'New message',
      'Elif',
    ]);
    expect(await b.shortcuts('camera'), isEmpty);
    await b.openAppInfo('maps');
    await b.uninstall('web');
    expect(b.appInfoRequests, ['maps']);
    expect(b.uninstallRequests, ['web']);
  });

  group('search sources', () {
    test('contacts from the design copy, gated by the permission', () async {
      final b = MockBackend();
      expect((await b.searchContacts('mi')).single.name, 'Mira Okafor');
      b.canSearchContacts = false;
      expect(await b.searchContacts('mi'), isEmpty);
      await b.requestContactsAccess();
      expect(b.contactsRequests, 1);
    });

    test('settings pages and opening them', () async {
      final b = MockBackend();
      expect(b.settingsPages, isNotEmpty);
      await b.openSettingsPage('battery');
      await b.openContact('elif');
      expect(b.settingsRequests, ['battery']);
      expect(b.contactRequests, ['elif']);
    });

    test('the mock has no assistant but records the ask', () async {
      final b = MockBackend();
      expect(await b.openAssistant(), isFalse);
      expect(b.assistantRequests, 1);
    });

    test('no private space', () {
      expect(MockBackend().privateSpace, PrivateSpaceState.none);
    });
  });

  group('notification actions', () {
    test('reply goes through for messages that can be replied to', () async {
      final b = MockBackend();
      expect(await b.replyToNotification('elif-1', 'Yes'), isTrue);
      expect(b.replies, [('elif-1', 'Yes')]);
      expect(await b.replyToNotification('nope', 'x'), isFalse);
    });

    test('dismiss and snooze remove it and notify', () async {
      final b = MockBackend();
      final before = b.notifications.length;
      final changed = expectLater(b.changes, emits(null));
      await b.dismissNotification('elif-1');
      await changed;
      await b.snoozeNotification('parcel-1');
      expect(b.notifications, hasLength(before - 2));
      expect(b.snoozed, ['parcel-1']);
    });

    test('actions, maps and events are recorded', () async {
      final b = MockBackend();
      await b.runNotificationAction('elif-1', '1');
      await b.openMap('Room 3');
      await b.openEvent('42');
      expect(b.actionsRun, [('elif-1', '1')]);
      expect(b.mapsOpened, ['Room 3']);
      expect(b.eventsOpened, ['42']);
    });

    test('open, access and seen are recorded', () async {
      final b = MockBackend();
      await b.openNotification('elif-1');
      await b.requestNotificationAccess();
      await b.requestCalendarAccess();
      b.markNotificationsSeen();
      expect(b.openedNotifications, ['elif-1']);
      expect(
        (b.notificationAccessRequests, b.calendarRequests, b.seenMarks),
        (1, 1, 1),
      );
      expect((b.canReadNotifications, b.canReadCalendar), (true, true));
    });
  });

  test('Elif has an action prompt', () {
    expect(backend.notifications.first.actionPrompt, 'Still on for 7?');
    expect(backend.notifications.last.actionPrompt, isNull);
  });

  group('quick settings', () {
    test('start as the Switchboard design', () {
      final b = MockBackend();
      final q = b.quick;
      expect((q.brightness * 100).round(), 64);
      expect(q.brightnessAuto, isTrue);
      expect((q.volume * 100).round(), 42);
      expect(q.volumeFooter, 'Media · ring');
      expect(q.toggles.map((t) => t.title), [
        'Wi-Fi',
        'Bluetooth',
        'Cellular',
        'Airplane',
        'Focus',
      ]);
      expect(q.toggles.map((t) => t.on), [true, true, true, false, true]);
      expect(q.media!.title, 'Night Drive');
      expect(q.media!.artist, 'Mira Okafor');
      expect(q.media!.progress, 0.42);
      expect(b.status.fullBy, '10:20');
    });

    test('setting brightness by hand turns auto off and notifies', () async {
      final b = MockBackend();
      final changed = b.changes.first;
      b.setBrightness(0.8);
      await changed;
      expect(b.quick.brightness, 0.8);
      expect(b.quick.brightnessAuto, isFalse);
    });

    test('values are clamped', () {
      final b = MockBackend();
      b.setBrightness(2);
      b.setVolume(-1);
      expect(b.quick.brightness, 1);
      expect(b.quick.volume, 0);
    });

    test('airplane switches the radios off but not Focus', () {
      final b = MockBackend();
      b.setToggle('airplane', true);
      final on = {for (final t in b.quick.toggles) t.id: t.on};
      expect(on['airplane'], isTrue);
      expect(on['wifi'], isFalse);
      expect(on['bluetooth'], isFalse);
      expect(on['cellular'], isFalse);
      expect(on['focus'], isTrue);
      expect(b.quick.toggles.firstWhere((t) => t.id == 'wifi').detail, 'Off');
    });

    test('leaving airplane does not turn the radios back on', () {
      final b = MockBackend();
      b.setToggle('airplane', true);
      b.setToggle('airplane', false);
      expect(b.quick.toggles.firstWhere((t) => t.id == 'wifi').on, isFalse);
    });

    test('access grants: giving one notifies and counts as granted', () async {
      final b = MockBackend();
      expect(
        b.accessGrants.where((g) => !g.granted).length,
        b.system.privacyAlerts,
      );
      final changed = b.changes.first;
      await b.openAccess('contacts');
      await changed;
      expect(
        b.accessGrants.firstWhere((g) => g.id == 'contacts').granted,
        isTrue,
      );
    });

    test('Android settings pages are asked for by section', () async {
      final b = MockBackend();
      await b.openAndroidSettings('sound');
      expect(b.openedSettings, ['sound']);
    });

    test('auto brightness turns on and off', () {
      final b = MockBackend();
      b.setBrightnessAuto(false);
      expect(b.quick.brightnessAuto, isFalse);
      b.setBrightnessAuto(true);
      expect(b.quick.brightnessAuto, isTrue);
    });

    test('skipping starts the next track from the top', () {
      final b = MockBackend();
      b.skipMedia(next: true);
      expect(b.quick.media!.progress, 0);
      expect(b.quick.media!.playing, isTrue);
    });

    test('play and pause', () {
      final b = MockBackend();
      b.setPlaying(false);
      expect(b.quick.media!.playing, isFalse);
    });
  });

  group('system', () {
    test('starts as the System design', () {
      final s = MockBackend().system;
      expect(s.account.initials, 'AS');
      expect(s.account.name, 'Avery Stone');
      expect(s.appearance, Appearance.dark);
      expect(s.textSizePx, 16);
      expect(s.focus, 'Work');
      expect(s.privacyAlerts, 2);
    });

    test('text size maps 0..1 onto 12..20 px', () {
      final b = MockBackend();
      b.setTextSize(0);
      expect(b.system.textSizePx, 12);
      b.setTextSize(1);
      expect(b.system.textSizePx, 20);
      b.setTextSize(5);
      expect(b.system.textSizePx, 20);
    });

    test('appearance changes and notifies', () async {
      final b = MockBackend();
      final changed = b.changes.first;
      b.setAppearance(Appearance.auto);
      await changed;
      expect(b.system.appearance, Appearance.auto);
    });
  });

  group('recents', () {
    test('start as the Recents design, with Maps in the middle', () {
      final r = MockBackend().recents.map((a) => a.id).toList();
      expect(r, ['messages', 'music', 'maps', 'notes', 'web']);
      expect(r[r.length ~/ 2], 'maps');
    });

    test('closing one removes it and notifies', () async {
      final b = MockBackend();
      final changed = b.changes.first;
      b.closeRecent('music');
      await changed;
      expect(b.recents.map((a) => a.id), ['messages', 'maps', 'notes', 'web']);
    });

    test('closing an unknown app does nothing', () {
      final b = MockBackend();
      b.closeRecent('nope');
      expect(b.recents, hasLength(5));
    });

    test('clear all empties Recents', () {
      final b = MockBackend();
      b.clearRecents();
      expect(b.recents, isEmpty);
    });

    test('the list cannot be modified from outside', () {
      expect(() => MockBackend().recents.clear(), throwsUnsupportedError);
    });
  });

  test('minutesUntil never goes negative', () {
    final e = backend.nextEvent!;
    expect(e.minutesUntil(DateTime(2026, 10, 23, 11)), 0);
  });

  test(
    'Lock previews are Elif (unread) then Parcel (read), with short copy',
    () {
      final n = backend.lockPreviews;
      expect(n.map((x) => x.sender), ['Elif', 'Parcel']);
      expect(n.map((x) => x.unread), [true, false]);
      expect(n.map((x) => x.age(backend.now)), ['2M', '1H']);
      expect(n.map((x) => x.preview), [
        'Are we still on for 7?',
        'Arriving 14:00 to 16:00',
      ]);
    },
  );

  group('Stream', () {
    test('order is what is in play now, then earlier', () {
      final n = backend.notifications;
      expect(n.map((x) => x.sender), ['Elif', 'Calendar', 'Parcel', 'Deniz']);
      expect(n.map((x) => x.mark), [
        StreamMark.current,
        StreamMark.alert,
        StreamMark.read,
        StreamMark.read,
      ]);
    });

    test('only the Elif message can be replied to', () {
      expect(backend.notifications.map((x) => x.canReply), [
        true,
        false,
        false,
        false,
      ]);
    });

    test('headers: source when set, else the sender', () {
      final n = backend.notifications;
      expect(n[0].source, 'Messages · Elif');
      expect(n[1].source, isNull);
      expect(n[3].source, 'Messages · Deniz');
    });

    test('Deniz wrote yesterday', () {
      final deniz = backend.notifications.last;
      expect(deniz.receivedAt.day, backend.now.day - 1);
    });

    test('digest: 11 read, 3 need you, 4 new', () {
      final s = backend.streamSummary;
      expect(s.read, 11);
      expect(s.newCount, 4);
      expect(s.needYou, hasLength(3));
      expect(s.needYou.first, 'Reply to Elif about dinner');
    });
  });

  test('age rolls over to hours and days, minimum 1M', () {
    final base = DateTime(2026, 10, 23, 12);
    HaloNotification at(Duration ago) => HaloNotification(
      id: 'x',
      app: 'a',
      sender: 's',
      body: 'b',
      receivedAt: base.subtract(ago),
      unread: false,
    );
    expect(at(const Duration(seconds: 5)).age(base), '1M');
    expect(at(const Duration(minutes: 59)).age(base), '59M');
    expect(at(const Duration(hours: 5)).age(base), '5H');
    expect(at(const Duration(days: 3)).age(base), '3D');
  });
}

/// The mock with more apps than the arc holds.
class _ManyApps extends MockBackend {
  @override
  List<HaloAppInfo> get apps => [
    ...super.apps,
    for (var i = 0; i < 12; i++) HaloAppInfo(id: 'x$i', label: 'App $i'),
  ];
}
