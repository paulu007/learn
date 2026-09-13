import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app_providers.dart';
import '../../core/constants/app_constants.dart';
import '../../data/import/csv_import.dart';
import '../../data/import/excel_import.dart';
import '../../widgets/common_widgets.dart';

/// CSV/Excel import: format example, copy, file pick, validation preview,
/// and confirmed import into a new or existing course.
class ImportScreen extends ConsumerStatefulWidget {
  const ImportScreen({super.key});

  @override
  ConsumerState<ImportScreen> createState() => _ImportScreenState();
}

class _ImportScreenState extends ConsumerState<ImportScreen> {
  final _csvService = CsvImportService();
  final _sourceCtrl = TextEditingController(text: 'English');
  final _targetCtrl = TextEditingController(text: 'Persian');

  ImportPreview? _preview;
  String? _fileName;
  bool _importing = false;

  @override
  void dispose() {
    _sourceCtrl.dispose();
    _targetCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['csv', 'xlsx', 'xls'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;
    final file = result.files.first;
    try {
      final preview = await _parsePicked(file);
      setState(() {
        _preview = preview;
        _fileName = file.name;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not read file: $e')),
        );
      }
    }
  }

  Future<ImportPreview> _parsePicked(PlatformFile file) async {
    final name = file.name.toLowerCase();
    if (name.endsWith('.csv')) {
      String text;
      if (file.bytes != null) {
        text = utf8.decode(file.bytes!, allowMalformed: true);
      } else if (file.path != null) {
        text = await File(file.path!).readAsString();
      } else {
        throw const FormatException('Empty file.');
      }
      // Strip BOM.
      if (text.startsWith('﻿')) text = text.substring(1);
      return _csvService.parseCsv(text);
    }
    if (name.endsWith('.xlsx') || name.endsWith('.xls')) {
      List<int> bytes;
      if (file.bytes != null) {
        bytes = file.bytes!;
      } else if (file.path != null) {
        bytes = await File(file.path!).readAsBytes();
      } else {
        throw const FormatException('Empty file.');
      }
      final grid = _excelServiceGrid(bytes);
      return _csvService.parseGrid(grid);
    }
    throw FormatException('Unsupported file type: ${file.name}');
  }

  List<List<String>> _excelServiceGrid(List<int> bytes) {
    // Reuse the shared reader (kept separate for testability).
    return ExcelImportService().readSheet(
      Uint8List.fromList(bytes),
    );
  }

  Future<void> _doImport() async {
    final preview = _preview;
    if (preview == null || preview.validRows.isEmpty) return;
    if (_sourceCtrl.text.trim().isEmpty || _targetCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter both languages first.')),
      );
      return;
    }
    setState(() => _importing = true);
    try {
      final repo = ref.read(repositoryProvider);
      final course = await repo.createCourse(
        _sourceCtrl.text,
        _targetCtrl.text,
      );
      var order = 0;
      final lessonIds = <String, String>{};
      for (final name in preview.lessons) {
        final lesson = await repo.findOrCreateLesson(
          course.id,
          name,
          order++,
        );
        lessonIds[name] = lesson.id;
      }
      final grouped = _csvService.groupByLesson(
        course.id,
        lessonIds,
        preview.validRows,
      );
      for (final entry in grouped.entries) {
        await repo.insertItems(entry.value);
      }
      ref.invalidate(coursesProvider);
      refreshAfterStudy(ref);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Imported ${preview.validRows.length} items into ${course.title}.',
            ),
          ),
        );
        Navigator.of(context).pop();
      }
    } finally {
      if (mounted) setState(() => _importing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Import Language Lesson')),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 12),
        children: [
          SectionCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Course languages',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _sourceCtrl,
                        decoration: const InputDecoration(
                          labelText: 'From (e.g. English)',
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: _targetCtrl,
                        decoration: const InputDecoration(
                          labelText: 'To (e.g. Persian)',
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          SectionCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'How should your CSV look?',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Theme.of(
                      context,
                    ).colorScheme.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const SelectableText(
                    AppConstants.csvExample,
                    style: TextStyle(fontFamily: 'monospace', fontSize: 12),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () =>
                            copyText(context, AppConstants.csvExample),
                        icon: const Icon(Icons.copy),
                        label: const Text('Copy Example'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: _pickFile,
                        icon: const Icon(Icons.folder_open),
                        label: const Text('Select File'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const Text(
                  'Accepted: .csv, .xlsx, .xls — same columns. '
                  'type: vocab, sentence, communication. '
                  'difficulty: easy, medium, hard.',
                ),
              ],
            ),
          ),
          if (_preview != null) _previewCard(context),
        ],
      ),
    );
  }

  Widget _previewCard(BuildContext context) {
    final preview = _preview!;
    final valid = preview.validRows.length;
    final invalid = preview.invalidRows.length;
    final lessons = preview.lessons.length;
    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Import Preview${_fileName == null ? '' : ' — $_fileName'}',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          if (preview.globalErrors.isNotEmpty)
            FeedbackBanner(
              correct: false,
              detail: preview.globalErrors.join('\n'),
            )
          else ...[
            Text(
              '${_sourceCtrl.text.trim()} → ${_targetCtrl.text.trim()}',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            Text('$valid valid items · $lessons lessons found'),
            if (invalid > 0)
              Text(
                '$invalid rows have problems',
                style: const TextStyle(
                  color: AppConstants.incorrectRed,
                  fontWeight: FontWeight.w600,
                ),
              ),
            const SizedBox(height: 8),
            if (invalid > 0)
              ExpansionTile(
                title: const Text('View Problems'),
                children: [
                  for (final r in preview.invalidRows.take(10))
                    ListTile(
                      dense: true,
                      title: Text('Row ${r.lineNumber}: ${r.source}'),
                      subtitle: Text(r.problems.join(' ')),
                    ),
                  if (invalid > 10) Text('…and ${invalid - 10} more.'),
                ],
              ),
            const SizedBox(height: 4),
            const Text('First rows:'),
            for (final r in preview.validRows.take(3))
              Text('• ${r.source} → ${r.target} (${r.type})'),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _importing
                        ? null
                        : () => setState(() => _preview = null),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton(
                    onPressed: (_importing || valid == 0) ? null : _doImport,
                    child: Text(
                      _importing ? 'Importing…' : 'Import Valid Rows ($valid)',
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
