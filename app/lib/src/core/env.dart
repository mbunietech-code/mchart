/// Build-time configuration. Override with:
///   flutter run --dart-define=MCHART_API=http://localhost:8000
/// Defaults point at production (https://chart.mbunie.tech).
abstract final class Env {
  static const apiBaseUrl = String.fromEnvironment(
    'MCHART_API',
    defaultValue: 'https://chart.mbunie.tech',
  );

  static String get apiV1 => '$apiBaseUrl/api/v1';
  static String get broadcastAuthUrl => '$apiBaseUrl/api/broadcasting/auth';

  /// Set MCHART_REALTIME=off to disable the WebSocket layer entirely.
  static const realtimeEnabled =
      String.fromEnvironment('MCHART_REALTIME', defaultValue: 'on') != 'off';

  // Laravel Reverb (Pusher protocol over plain WebSocket). The key is the
  // public Pusher app key, the same one run-prod.ps1 passes.
  static const reverbKey = String.fromEnvironment(
    'MCHART_REVERB_KEY',
    defaultValue: '03120d5a258eafdde73d09ffbdeb515d1c2d58d8',
  );
  static const reverbHost = String.fromEnvironment(
    'MCHART_REVERB_HOST',
    defaultValue: 'ws.mbunie.tech',
  );
  static const reverbPort = int.fromEnvironment(
    'MCHART_REVERB_PORT',
    defaultValue: 443,
  );
  static const reverbScheme = String.fromEnvironment(
    'MCHART_REVERB_SCHEME',
    defaultValue: 'wss',
  );

  static Uri get reverbUri => Uri(
    scheme: reverbScheme,
    host: reverbHost,
    port: reverbPort,
    path: '/app/$reverbKey',
    queryParameters: {
      'protocol': '7',
      'client': 'mchart-flutter',
      'version': '1.0',
    },
  );
}
