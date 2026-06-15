class RecordedVoiceNote {
  const RecordedVoiceNote({
    required this.dataUrl,
    required this.mimeType,
    required this.sizeBytes,
  });

  final String dataUrl;
  final String mimeType;
  final int sizeBytes;
}

class BrowserVoiceRecorder {
  Future<void> start() async {
    throw UnsupportedError(
      'Voice recording is available in supported browsers.',
    );
  }

  Future<RecordedVoiceNote> stop() async {
    throw UnsupportedError(
      'Voice recording is available in supported browsers.',
    );
  }

  void dispose() {}
}
