import 'dart:async';
import 'dart:html' as html;

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
  html.MediaRecorder? _recorder;
  html.MediaStream? _stream;
  final List<html.Blob> _chunks = [];

  Future<void> start() async {
    final mediaDevices = html.window.navigator.mediaDevices;
    if (mediaDevices == null) {
      throw StateError('Microphone access is not available in this browser.');
    }

    _chunks.clear();
    _stream = await mediaDevices.getUserMedia({'audio': true});
    final mimeType =
        html.MediaRecorder.isTypeSupported('audio/webm;codecs=opus')
        ? 'audio/webm;codecs=opus'
        : 'audio/webm';
    _recorder = html.MediaRecorder(_stream!, {'mimeType': mimeType});
    _recorder!.addEventListener('dataavailable', (event) {
      final blobEvent = event as html.BlobEvent;
      final data = blobEvent.data;
      if (data != null && data.size > 0) {
        _chunks.add(data);
      }
    });
    _recorder!.start();
  }

  Future<RecordedVoiceNote> stop() async {
    final recorder = _recorder;
    if (recorder == null) {
      throw StateError('No active voice recording found.');
    }

    final stopped = Completer<void>();
    late html.EventListener stopListener;
    stopListener = (event) {
      recorder.removeEventListener('stop', stopListener);
      if (!stopped.isCompleted) stopped.complete();
    };
    recorder.addEventListener('stop', stopListener);
    recorder.stop();
    await stopped.future;

    final String mimeType = recorder.mimeType?.isNotEmpty == true
        ? recorder.mimeType!
        : 'audio/webm';
    final blob = html.Blob(_chunks, mimeType);
    final reader = html.FileReader();
    final loaded = Completer<void>();
    reader.onLoad.first.then((_) => loaded.complete());
    reader.readAsDataUrl(blob);
    await loaded.future;

    _stopTracks();
    _recorder = null;
    _chunks.clear();

    return RecordedVoiceNote(
      dataUrl: reader.result?.toString() ?? '',
      mimeType: mimeType,
      sizeBytes: blob.size,
    );
  }

  void dispose() {
    _stopTracks();
    _recorder = null;
    _chunks.clear();
  }

  void _stopTracks() {
    for (final track
        in _stream?.getTracks() ?? const <html.MediaStreamTrack>[]) {
      track.stop();
    }
    _stream = null;
  }
}
