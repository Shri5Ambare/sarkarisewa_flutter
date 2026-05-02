import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

class CsvExporter {
  static Future<void> exportAndShare(List<Map<String, dynamic>> data, String filenamePrefix) async {
    if (data.isEmpty) return;

    final headers = data.first.keys.toList();
    final rows = <List<dynamic>>[];
    rows.add(headers);
    for (var map in data) {
      final row = <dynamic>[];
      for (var key in headers) {
        row.add(map[key]?.toString() ?? '');
      }
      rows.add(row);
    }

    final buffer = StringBuffer();
    for (var row in rows) {
      buffer.writeln(row.map((e) => '"${e.toString().replaceAll('"', '""')}"').join(','));
    }
    final csvString = buffer.toString();

    final directory = await getTemporaryDirectory();
    final timestamp = DateTime.now().toIso8601String().replaceAll(':', '-').split('.')[0];
    final path = '${directory.path}/${filenamePrefix}_$timestamp.csv';
    await File(path).writeAsString(csvString);

    await SharePlus.instance.share(
        ShareParams(files: [XFile(path)], text: 'Exported $filenamePrefix Data'));
  }

  static Future<void> exportJson(String jsonStr, String filename) async {
    final directory = await getTemporaryDirectory();
    final path = '${directory.path}/$filename';
    await File(path).writeAsString(jsonStr);
    await SharePlus.instance.share(
        ShareParams(files: [XFile(path)], text: 'Exported user data'));
  }

  static Future<void> exportTransactionsCsv(
      List<Map<String, dynamic>> data, String filename) async {
    await exportAndShare(data, filename);
  }
}
