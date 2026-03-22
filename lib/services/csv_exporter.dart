import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

class CsvExporter {
  static Future<void> exportAndShare(List<Map<String, dynamic>> data, String filenamePrefix) async {
    if (data.isEmpty) return;

    // 1. Extract headers from the first map
    final headers = data.first.keys.toList();
    
    // 2. Build rows
    final rows = <List<dynamic>>[];
    rows.add(headers);
    for (var map in data) {
      final row = <dynamic>[];
      for (var key in headers) {
        row.add(map[key]?.toString() ?? '');
      }
      rows.add(row);
    }

    // 3. Convert to CSV string manually
    final buffer = StringBuffer();
    for (var row in rows) {
      buffer.writeln(row.map((e) => '"${e.toString().replaceAll('"', '""')}"').join(','));
    }
    final csvString = buffer.toString();

    // 4. Save to temporary directory
    final directory = await getTemporaryDirectory();
    final timestamp = DateTime.now().toIso8601String().replaceAll(':', '-').split('.')[0];
    final path = '${directory.path}/${filenamePrefix}_$timestamp.csv';
    final file = File(path);
    await file.writeAsString(csvString);

    // 5. Share the file leveraging the OS
    // ignore: deprecated_member_use
    await Share.shareXFiles([XFile(path)], text: 'Exported $filenamePrefix Data');
  }
}
