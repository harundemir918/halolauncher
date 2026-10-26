import 'models.dart';

/// The settings pages search offers, by id. Each backend maps the ids to its
/// own screens (`packages/halo_android` to `android.provider.Settings`).
const defaultSettingsPages = [
  SettingsPage(id: 'wifi', label: 'Wi-Fi'),
  SettingsPage(id: 'bluetooth', label: 'Bluetooth'),
  SettingsPage(id: 'network', label: 'Mobile network'),
  SettingsPage(id: 'airplane', label: 'Airplane mode'),
  SettingsPage(id: 'display', label: 'Display'),
  SettingsPage(id: 'sound', label: 'Sound'),
  SettingsPage(id: 'notifications', label: 'Notifications'),
  SettingsPage(id: 'battery', label: 'Battery'),
  SettingsPage(id: 'apps', label: 'Apps'),
  SettingsPage(id: 'location', label: 'Location'),
  SettingsPage(id: 'security', label: 'Security'),
  SettingsPage(id: 'privacy', label: 'Privacy'),
  SettingsPage(id: 'storage', label: 'Storage'),
  SettingsPage(id: 'accessibility', label: 'Accessibility'),
  SettingsPage(id: 'datetime', label: 'Date & time'),
  SettingsPage(id: 'language', label: 'Language & input'),
  SettingsPage(id: 'home', label: 'Default home app'),
  SettingsPage(id: 'about', label: 'About phone'),
];
