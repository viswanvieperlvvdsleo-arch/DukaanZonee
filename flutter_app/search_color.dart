import 'dart:io';

void main() {
  final query = '7497d5';
  final dir = Directory('lib');
  final resultsFile = File('search_results.txt');
  final sink = resultsFile.openWrite();
  
  if (dir.existsSync()) {
    dir.listSync(recursive: true).forEach((entity) {
      if (entity is File && entity.path.endsWith('.dart')) {
        try {
          final content = entity.readAsStringSync();
          final lines = content.split('\n');
          for (int i = 0; i < lines.length; i++) {
            if (lines[i].toLowerCase().contains(query.toLowerCase())) {
              sink.writeln('${entity.path}:${i + 1}: ${lines[i].trim()}');
            }
          }
        } catch (e) {
          // ignore
        }
      }
    });
  }
  sink.close();
  print('Done');
}
