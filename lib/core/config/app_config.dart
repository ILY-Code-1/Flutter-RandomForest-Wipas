/// Build-time configuration (pass with `--dart-define`).
class AppConfig {
  AppConfig._();

  /// Default warehouse (Hub Cakung).
  static const defaultWhId = 'WH-CKG-01';

  /// Use the local Firebase Emulator (default). Set to false only after
  /// `flutterfire configure` has generated real options.
  static const useEmulator = bool.fromEnvironment('USE_EMULATOR', defaultValue: true);

  /// Emulator host. `10.0.2.2` is the host machine as seen from the Android
  /// emulator; use the LAN IP of the computer for a physical device.
  static const emulatorHost = String.fromEnvironment('EMULATOR_HOST', defaultValue: '10.0.2.2');
  static const authEmulatorPort = 9099;
  static const firestoreEmulatorPort = 8080;

  /// Show the demo role shortcuts on Login (emulator / demo builds only).
  static const showDemoLogin = bool.fromEnvironment('SHOW_DEMO_LOGIN', defaultValue: useEmulator);

  /// Session lifetime before automatic sign-out.
  static const sessionLifetime = Duration(hours: 24);

  static const appVersion = '1.0.0';
  static const appBuild = '1';

  /// Demo accounts created by `firebase/seed/seed.dart` (emulator only).
  static const demoPassword = 'wipas-demo-123';
  static const demoAccounts = <String, String>{
    'Admin · Shift Lead': 'admin.shift@wipas.example',
    'Manajer Warehouse': 'manajer@wipas.example',
    'Supervisor': 'supervisor@wipas.example',
    'Viewer · Tim DI': 'viewer@wipas.example',
  };
}
