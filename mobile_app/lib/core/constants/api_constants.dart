class ApiConstants {
  ApiConstants._();

  /// Anwani ya backend. Default ni localhost (Chrome/desktop).
  /// Kwa simu: flutter run --dart-define=SERVER_URL=http://192.168.x.x:8080
  static const String serverUrl = String.fromEnvironment(
    'SERVER_URL',
    defaultValue: 'http://localhost:8080',
  );

  static const String baseUrl = '$serverUrl/api';

  /// http -> ws, https -> wss
  static final String wsUrl = '${serverUrl.replaceFirst('http', 'ws')}/ws';
}
