import 'dart:io';

void main() {
  final file = File(r'lib\ui\pages\seller\b2b_chat_page.dart');
  if (!file.existsSync()) {
    print('File not found: ${file.absolute.path}');
    return;
  }
  final lines = file.readAsLinesSync();
  for (int i = 0; i < lines.length; i++) {
    final line = lines[i];
    if (line.contains('_showAttachmentPanel') ||
        line.contains('_showEmojiSelector') ||
        line.contains('_isRecordingVoice') ||
        line.contains('_showFolderExplorer') ||
        line.contains('_showImageEditor')) {
      print('${i + 1}: $line');
    }
  }
}
