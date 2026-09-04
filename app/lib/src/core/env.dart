/// Build-time configuration. Override with:
///   flutter run --dart-define=MCHART_API=https://api.mbunietech.com
abstract final class Env {
  static const apiBaseUrl = String.fromEnvironment(
    'MCHART_API',
    defaultValue: 'http://localhost:8000',
  );

  static String get apiV1 => '$apiBaseUrl/api/v1';
  static String get broadcastAuthUrl => '$apiBaseUrl/api/broadcasting/auth';

  /// Set MCHART_REALTIME=off to disable the WebSocket layer entirely.
  static const realtimeEnabled =
      String.fromEnvironment('MCHART_REALTIME', defaultValue: 'on') != 'off';

  // Laravel Reverb (Pusher protocol over plain WebSocket).
  static const reverbKey = String.fromEnvironment(
    'MCHART_REVERB_KEY',
    defaultValue: 'mchart-local-key',
  );
  static const reverbHost = String.fromEnvironment(
    'MCHART_REVERB_HOST',
    defaultValue: 'localhost',
  );
  static const reverbPort = int.fromEnvironment('MCHART_REVERB_PORT', defaultValue: 8080);
  static const reverbScheme = String.fromEnvironment(
    'MCHART_REVERB_SCHEME',
    defaultValue: 'ws',
  );

  static Uri get reverbUri => Uri(
        scheme: reverbScheme,
        host: reverbHost,
        port: reverbPort,
        path: '/app/$reverbKey',
        queryParameters: {'protocol': '7', 'client': 'mchart-flutter', 'version': '1.0'},
      );
}
