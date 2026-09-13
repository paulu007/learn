import 'dart:typed_data';

import 'package:excel/excel.dart';

/// Reads the first non-empty sheet of an .xlsx/.xls file into a string grid.
/// The grid's first row is the header; validation happens in
/// [CsvImportService.parseGrid] so Excel shares the CSV rules.
class ExcelImportService {
  List<List<String>> readSheet(Uint8List bytes) {
    final excel = Excel.decodeBytes(bytes);
    if (excel.tables.isEmpty) {
      throw const FormatException('The workbook has no sheets.');
    }
    Sheet? best;
    for (final sheet in excel.tables.values) {
      final nonEmpty = sheet.rows.any(
        (r) => r.any((c) => (c?.value?.toString() ?? '').trim().isNotEmpty),
      );
      if (nonEmpty) {
        best = sheet;
        break;
      }
    }
    final sheet = best ?? excel.tables.values.first;
    return sheet.rows
        .map(
          (r) => r.map((c) {
            final v = c?.value;
            if (v == null) return '';
            if (v is DoubleCellValue && v.value == v.value.roundToDouble()) {
              return v.value.toInt().toString();
            }
            if (v is DateCellValue) {
              return '${v.year.toString().padLeft(4, '0')}-'
                  '${v.month.toString().padLeft(2, '0')}-'
                  '${v.day.toString().padLeft(2, '0')}';
            }
            return v.toString().trim();
          }).toList(),
        )
        .toList();
  }
}
