// lib/widgets/admin/bulk_import_view.dart
//
// Phase 4.1 — Bulk import for courses / mock-tests / PYQs / news / live classes.
// Flow: pick CSV or JSON → parse → dry-run validation → diff preview → confirm.
import 'dart:convert';
import 'package:csv/csv.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../../services/firestore_service.dart';
import '../../theme.dart';

class BulkImportView extends StatefulWidget {
  const BulkImportView({super.key});

  @override
  State<BulkImportView> createState() => _BulkImportViewState();
}

class _BulkImportViewState extends State<BulkImportView> {
  final _db = FirestoreService();
  String _collection = 'news';
  List<Map<String, dynamic>> _parsed = [];
  List<String> _errors = [];
  bool _validated = false;
  bool _importing = false;
  String? _resultMsg;

  static const _collections = [
    'news',
    'courses',
    'mock_tests',
    'pyqs',
    'live_classes',
  ];

  Future<void> _pickFile() async {
    setState(() {
      _parsed = [];
      _errors = [];
      _validated = false;
      _resultMsg = null;
    });

    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['csv', 'json'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;

    final file = result.files.first;
    final bytes = file.bytes;
    if (bytes == null) return;
    final text = utf8.decode(bytes);

    try {
      List<Map<String, dynamic>> rows;
      if (file.extension?.toLowerCase() == 'json') {
        final decoded = json.decode(text);
        if (decoded is List) {
          rows = decoded.cast<Map<String, dynamic>>();
        } else if (decoded is Map) {
          rows = [decoded.cast<String, dynamic>()];
        } else {
          throw const FormatException('JSON must be an array or object');
        }
      } else {
        // CSV
        final csvRows = const CsvDecoder().convert(text);
        if (csvRows.isEmpty) throw const FormatException('Empty CSV');
        final headers =
            csvRows.first.map((h) => h.toString().trim()).toList();
        rows = csvRows
            .skip(1)
            .map((row) {
              final map = <String, dynamic>{};
              for (var i = 0; i < headers.length; i++) {
                map[headers[i]] = i < row.length ? row[i] : null;
              }
              return map;
            })
            .where((r) => r.values.any((v) => v != null && v.toString().isNotEmpty))
            .toList();
      }

      final errs = _db.validateImportDocs(_collection, rows);
      setState(() {
        _parsed = rows;
        _errors = errs;
        _validated = true;
      });
    } catch (e) {
      setState(() {
        _errors = ['Parse error: $e'];
        _validated = true;
      });
    }
  }

  Future<void> _commit() async {
    if (_parsed.isEmpty || _errors.isNotEmpty) return;
    setState(() => _importing = true);
    try {
      final count = await _db.bulkImportDocs(_collection, _parsed);
      setState(() => _resultMsg = '✅ Imported $count documents into $_collection');
      _parsed = [];
      _errors = [];
      _validated = false;
    } catch (e) {
      setState(() => _resultMsg = '❌ Import failed: $e');
    } finally {
      setState(() => _importing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(padding: const EdgeInsets.all(16), children: [
      const Text('📥 Bulk Import',
          style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary)),
      const SizedBox(height: 4),
      const Text(
        'Upload a CSV or JSON file to seed content. A dry-run preview '
        'shows validation errors before any writes.',
        style: TextStyle(color: AppColors.textMuted, fontSize: 12),
      ),
      const SizedBox(height: 16),

      // Collection picker
      Row(children: [
        const Text('Collection:',
            style: TextStyle(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w600,
                fontSize: 13)),
        const SizedBox(width: 10),
        DropdownButton<String>(
          value: _collection,
          dropdownColor: AppColors.navyMid,
          style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 13,
              fontWeight: FontWeight.w600),
          underline: Container(height: 1, color: AppColors.border),
          items: _collections
              .map((c) => DropdownMenuItem(value: c, child: Text(c)))
              .toList(),
          onChanged: (v) {
            if (v != null) {
              setState(() {
                _collection = v;
                _parsed = [];
                _errors = [];
                _validated = false;
              });
            }
          },
        ),
      ]),
      const SizedBox(height: 12),

      // Pick file button
      OutlinedButton.icon(
        icon: const Icon(Icons.upload_file, size: 18),
        label: Text(_parsed.isEmpty
            ? 'Pick CSV / JSON file'
            : 'Re-pick (${_parsed.length} rows loaded)'),
        onPressed: _pickFile,
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primary,
          side: const BorderSide(color: AppColors.primary),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
      ),

      if (_resultMsg != null) ...[
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: _resultMsg!.startsWith('✅')
                ? AppColors.emerald.withAlpha(20)
                : AppColors.ruby.withAlpha(20),
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(
                color: _resultMsg!.startsWith('✅')
                    ? AppColors.emerald.withAlpha(60)
                    : AppColors.ruby.withAlpha(60)),
          ),
          child: Text(_resultMsg!,
              style: TextStyle(
                  color: _resultMsg!.startsWith('✅')
                      ? AppColors.emerald
                      : AppColors.ruby,
                  fontSize: 13)),
        ),
      ],

      if (_validated && _errors.isNotEmpty) ...[
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.ruby.withAlpha(15),
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(color: AppColors.ruby.withAlpha(60)),
          ),
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('⚠ Validation errors — fix before importing:',
                    style: TextStyle(
                        color: AppColors.ruby,
                        fontWeight: FontWeight.w700,
                        fontSize: 13)),
                const SizedBox(height: 6),
                ..._errors.map((e) => Padding(
                      padding: const EdgeInsets.only(bottom: 3),
                      child: Text('• $e',
                          style: const TextStyle(
                              color: AppColors.ruby, fontSize: 12)),
                    )),
              ]),
        ),
      ],

      if (_validated && _parsed.isNotEmpty) ...[
        const SizedBox(height: 16),
        Row(children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
                color: AppColors.emerald.withAlpha(20),
                borderRadius: BorderRadius.circular(AppRadius.pill),
                border: Border.all(color: AppColors.emerald.withAlpha(60))),
            child: Text('${_parsed.length} rows ready',
                style: const TextStyle(
                    color: AppColors.emerald,
                    fontWeight: FontWeight.w700,
                    fontSize: 12)),
          ),
          const SizedBox(width: 8),
          if (_errors.isEmpty)
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                  color: AppColors.primary.withAlpha(20),
                  borderRadius: BorderRadius.circular(AppRadius.pill)),
              child: const Text('✓ Validated',
                  style: TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w700,
                      fontSize: 12)),
            ),
        ]),
        const SizedBox(height: 10),

        // Preview table (first 5 rows)
        const Text('Preview (first 5 rows):',
            style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        _PreviewTable(rows: _parsed.take(5).toList()),

        const SizedBox(height: 16),
        if (_errors.isEmpty)
          _importing
              ? const Center(
                  child: CircularProgressIndicator(color: AppColors.primary))
              : ElevatedButton.icon(
                  icon: const Icon(Icons.cloud_upload, size: 18),
                  label: Text('Import ${_parsed.length} docs → $_collection'),
                  onPressed: _commit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 14),
                  ),
                ),
      ],
    ]);
  }
}

class _PreviewTable extends StatelessWidget {
  final List<Map<String, dynamic>> rows;
  const _PreviewTable({required this.rows});

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) return const SizedBox();
    final keys = rows.first.keys.take(6).toList();
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Table(
        border: TableBorder.all(color: AppColors.border, width: 0.5),
        defaultColumnWidth: const IntrinsicColumnWidth(),
        children: [
          TableRow(
            decoration: const BoxDecoration(color: AppColors.navyLight),
            children: keys
                .map((k) => _cell(k, isHeader: true))
                .toList(),
          ),
          ...rows.map((row) => TableRow(
                children: keys
                    .map((k) => _cell(row[k]?.toString() ?? ''))
                    .toList(),
              )),
        ],
      ),
    );
  }

  Widget _cell(String text, {bool isHeader = false}) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        child: Text(
          text.length > 30 ? '${text.substring(0, 28)}…' : text,
          style: TextStyle(
            fontSize: 11,
            fontWeight: isHeader ? FontWeight.w700 : FontWeight.w400,
            color: isHeader
                ? AppColors.textSecondary
                : AppColors.textPrimary,
          ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
      );
}
