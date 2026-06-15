import 'dart:io' show Platform;

String defaultApiBaseUrl() {
  if (Platform.isAndroid) {
    return 'http://10.0.2.2:4000';
  }
  return 'http://localhost:4000';
}
