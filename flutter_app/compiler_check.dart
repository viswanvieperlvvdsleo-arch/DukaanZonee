import 'dart:io';

void main() async {
  print('Starting flutter build web...');
  final result = await Process.run('flutter', ['build', 'web'], runInShell: true);
  
  final file = File('compile_output.txt');
  await file.writeAsString('STDOUT:\n${result.stdout}\n\nSTDERR:\n${result.stderr}');
  print('Done writing to compile_output.txt');
}
