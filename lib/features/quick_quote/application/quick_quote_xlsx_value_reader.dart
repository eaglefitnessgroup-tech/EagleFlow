import 'dart:convert';

import 'package:archive/archive.dart';
import 'package:xml/xml.dart';

/// Reads only cell values from an OOXML workbook and intentionally ignores
/// styles, drawings, merged cells, and formatting.
class QuickQuoteXlsxValueReader {
  Map<String, List<List<String>>> read(List<int> bytes) {
    final Archive archive;
    try {
      archive = ZipDecoder().decodeBytes(bytes);
    } catch (_) {
      throw const FormatException(
        'The selected file is not a readable .xlsx workbook.',
      );
    }

    try {
      final sharedStrings = _readSharedStrings(archive);
      final workbook = _xml(archive, 'xl/workbook.xml');
      final relationships = _xml(archive, 'xl/_rels/workbook.xml.rels');
      final relationshipTargets = <String, String>{
        for (final relationship
            in relationships.descendants.whereType<XmlElement>())
          if (relationship.name.local == 'Relationship')
            relationship.getAttribute('Id') ?? '':
                relationship.getAttribute('Target') ?? '',
      };

      final result = <String, List<List<String>>>{};
      for (final sheet in workbook.descendants.whereType<XmlElement>().where(
        (element) => element.name.local == 'sheet',
      )) {
        final name = sheet.getAttribute('name');
        final relationshipId = sheet.attributes
            .where((attribute) => attribute.name.local == 'id')
            .map((attribute) => attribute.value)
            .firstOrNull;
        final target = relationshipTargets[relationshipId];
        if (name == null || target == null || target.isEmpty) continue;
        result[name] = _readSheet(
          archive,
          _resolveWorkbookTarget(target),
          sharedStrings,
        );
      }
      if (result.isEmpty) {
        throw const FormatException(
          'The workbook contains no readable sheets.',
        );
      }
      return result;
    } on FormatException {
      rethrow;
    } catch (_) {
      throw const FormatException(
        'The selected file is not a readable .xlsx workbook.',
      );
    }
  }

  List<String> _readSharedStrings(Archive archive) {
    final file = _find(archive, 'xl/sharedStrings.xml');
    if (file == null) return const [];
    final document = XmlDocument.parse(_text(file));
    return document.descendants
        .whereType<XmlElement>()
        .where((element) => element.name.local == 'si')
        .map(
          (item) => item.descendants
              .whereType<XmlElement>()
              .where((element) => element.name.local == 't')
              .map((element) => element.innerText)
              .join(),
        )
        .toList(growable: false);
  }

  List<List<String>> _readSheet(
    Archive archive,
    String path,
    List<String> sharedStrings,
  ) {
    final document = _xml(archive, path);
    final rows = <List<String>>[];
    for (final row in document.descendants.whereType<XmlElement>().where(
      (element) => element.name.local == 'row',
    )) {
      final rowNumber =
          int.tryParse(row.getAttribute('r') ?? '') ?? rows.length + 1;
      while (rows.length < rowNumber) {
        rows.add(<String>[]);
      }
      final values = <String>[];
      for (final cell in row.children.whereType<XmlElement>().where(
        (element) => element.name.local == 'c',
      )) {
        final column = _columnIndex(cell.getAttribute('r') ?? '');
        while (values.length <= column) {
          values.add('');
        }
        values[column] = _cellText(cell, sharedStrings);
      }
      rows[rowNumber - 1] = values;
    }
    return rows;
  }

  String _cellText(XmlElement cell, List<String> sharedStrings) {
    final type = cell.getAttribute('t');
    if (type == 'inlineStr') {
      return cell.descendants
          .whereType<XmlElement>()
          .where((element) => element.name.local == 't')
          .map((element) => element.innerText)
          .join();
    }
    final raw = cell.children
        .whereType<XmlElement>()
        .where((element) => element.name.local == 'v')
        .map((element) => element.innerText)
        .firstOrNull;
    if (raw == null) return '';
    if (type == 's') {
      final index = int.tryParse(raw);
      return index != null && index >= 0 && index < sharedStrings.length
          ? sharedStrings[index]
          : '';
    }
    if (type == 'b') return raw == '1' ? 'TRUE' : 'FALSE';
    return raw;
  }

  int _columnIndex(String reference) {
    var result = 0;
    var found = false;
    for (final codeUnit in reference.codeUnits) {
      if (codeUnit < 65 || codeUnit > 90) break;
      found = true;
      result = result * 26 + codeUnit - 64;
    }
    return found ? result - 1 : 0;
  }

  String _resolveWorkbookTarget(String target) {
    if (target.startsWith('/')) return target.substring(1);
    var normalized = target;
    while (normalized.startsWith('../')) {
      normalized = normalized.substring(3);
    }
    if (normalized.startsWith('xl/')) return normalized;
    return 'xl/${normalized.replaceFirst(RegExp(r'^\./'), '')}';
  }

  XmlDocument _xml(Archive archive, String path) {
    final file = _find(archive, path);
    if (file == null) throw FormatException('The workbook is missing $path.');
    return XmlDocument.parse(_text(file));
  }

  ArchiveFile? _find(Archive archive, String path) {
    for (final file in archive) {
      if (file.name == path) return file;
    }
    return null;
  }

  String _text(ArchiveFile file) => utf8.decode(file.content as List<int>);
}
