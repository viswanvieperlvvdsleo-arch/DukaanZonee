import 'dart:io';
import 'dart:convert';

void main() async {
  final file = File('C:/Users/WHO ME!/.gemini/antigravity/brain/ce5a56da-a6c2-431a-893e-353407bb64c6/.system_generated/logs/transcript.jsonl');
  if (!await file.exists()) {
    print('File does not exist');
    return;
  }
  final lines = await file.readAsLines();
  print('Total lines: ${lines.length}');
  final tail = lines.sublist(lines.length > 20 ? lines.length - 20 : 0);
  for (var line in tail) {
    try {
      final data = json.decode(line);
      print('Step ${data['step_index']}: ${data['type']} - ${data['status']}');
      if (data['content'] != null) {
        print('  Content: ${data['content'].toString().substring(0, data['content'].toString().length > 100 ? 100 : data['content'].toString().length)}');
      }
      if (data['tool_calls'] != null) {
        print('  Tool calls: ${data['tool_calls']}');
      }
    } catch (e) {
      print('Error parsing line: $e');
    }
  }
}
