import 'package:halo_sdk/halo_sdk.dart';
import 'package:test/test.dart';

void main() {
  const apps = [
    HaloAppInfo(id: 'a', label: 'Google Maps'),
    HaloAppInfo(id: 'b', label: 'Maps.me'),
    HaloAppInfo(id: 'c', label: 'Messages'),
    HaloAppInfo(id: 'd', label: 'Şikayetvar'),
    HaloAppInfo(id: 'e', label: 'İş Bankası'),
    HaloAppInfo(id: 'f', label: 'Getir'),
  ];

  List<String> ids(String q) => [for (final a in searchApps(apps, q)) a.id];

  test('label prefix, then word prefix, then anywhere', () {
    expect(ids('map'), ['b', 'a']);
    expect(ids('ap'), ['a', 'b']);
  });

  test('ignores case and Turkish letters', () {
    expect(ids('sik'), ['d']);
    expect(ids('ŞİK'), ['d']);
    expect(ids('is ban'), ['e']);
    expect(ids('banka'), ['e']);
  });

  test('an empty or blank query matches nothing', () {
    expect(ids(''), isEmpty);
    expect(ids('   '), isEmpty);
  });

  test('no match is empty', () => expect(ids('zzz'), isEmpty));

  test('folding', () {
    expect(foldForSearch('İstanbul'), 'istanbul');
    expect(foldForSearch('IŞIK'), 'isik');
    expect(foldForSearch('Café'), 'cafe');
  });
}
