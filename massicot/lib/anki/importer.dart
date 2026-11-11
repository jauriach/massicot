import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';

import 'clean.dart';
import 'sqlite_reader.dart';

/// Carte lue dans un fichier Anki, déjà nettoyée.
class ImportedCard {
  ImportedCard({
    required this.front,
    required this.back,
    this.hadMedia = false,
    this.wasCloze = false,
    this.extraFields = 0,
  });

  final String front;
  final String back;

  /// Une image ou un son a été retiré.
  final bool hadMedia;

  /// La note était un texte à trous, converti en question / réponse.
  final bool wasCloze;

  /// Nombre de champs non vides au-delà des deux premiers (ignorés).
  final int extraFields;
}

class AnkiImportException implements Exception {
  AnkiImportException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Lit un export AnkiMobile / Anki : paquet `.apkg` ou `.colpkg`, ou export
/// texte (`.txt`, séparé par des tabulations).
List<ImportedCard> importAnkiFile(Uint8List bytes) {
  if (bytes.length >= 2 && bytes[0] == 0x50 && bytes[1] == 0x4b) {
    return _fromPackage(bytes);
  }
  if (bytes.length >= 15 &&
      String.fromCharCodes(bytes.sublist(0, 15)) == 'SQLite format 3') {
    return _fromDatabase(bytes);
  }
  return importAnkiText(utf8.decode(bytes, allowMalformed: true));
}

// ---------------------------------------------------------------- paquet

List<ImportedCard> _fromPackage(Uint8List bytes) {
  final Archive archive;
  try {
    archive = ZipDecoder().decodeBytes(bytes);
  } catch (_) {
    throw AnkiImportException('Le paquet est illisible (archive corrompue).');
  }
  ArchiveFile? legacy;
  ArchiveFile? legacy21;
  var hasNewFormat = false;
  for (final f in archive.files) {
    if (f.name == 'collection.anki21') legacy21 = f;
    if (f.name == 'collection.anki2') legacy = f;
    if (f.name == 'collection.anki21b') hasNewFormat = true;
  }
  final chosen = legacy21 ?? (hasNewFormat ? null : legacy);
  if (chosen == null) {
    if (hasNewFormat) {
      throw AnkiImportException(
        'Ce paquet utilise le nouveau format compressé d\'Anki, qui n\'est '
        'pas pris en charge.\n\nDans AnkiMobile, refaites l\'export en '
        'activant « Prendre en charge les anciennes versions d\'Anki » '
        '(Support older Anki versions), ou exportez en texte.',
      );
    }
    throw AnkiImportException(
        'Aucune collection Anki trouvée dans ce fichier.');
  }
  final Object? content = chosen.content;
  final data = content is Uint8List
      ? content
      : Uint8List.fromList((content as List).cast<int>());
  return _fromDatabase(data);
}

List<ImportedCard> _fromDatabase(Uint8List data) {
  try {
    final db = SqliteReader(data);
    var fldsIndex = db.columns('notes').indexOf('flds');
    if (fldsIndex < 0) fldsIndex = 6;
    final cards = <ImportedCard>[];
    for (final row in db.readTable('notes')) {
      if (row.length <= fldsIndex) continue;
      final flds = row[fldsIndex];
      if (flds is! String) continue;
      final card = cardFromFields(flds.split('\u001f'));
      if (card != null) cards.add(card);
    }
    return cards;
  } on SqliteFormatException catch (e) {
    throw AnkiImportException('Collection Anki illisible : ${e.message}');
  } on RangeError {
    throw AnkiImportException('Collection Anki illisible (fichier tronqué).');
  }
}

// ------------------------------------------------------------------ texte

/// Export « Notes en texte brut » d'Anki / AnkiMobile.
List<ImportedCard> importAnkiText(String text) {
  if (text.startsWith('﻿')) text = text.substring(1);
  String? sep;
  final skip = <int>{};
  var pos = 0;
  while (pos < text.length && text[pos] == '#') {
    var end = text.indexOf('\n', pos);
    if (end < 0) end = text.length;
    final line = text.substring(pos + 1, end).replaceAll('\r', '');
    final colon = line.indexOf(':');
    if (colon > 0) {
      final key = line.substring(0, colon).trim().toLowerCase();
      final value = line.substring(colon + 1);
      if (key == 'separator') {
        sep = _separator(value);
      } else if (key.endsWith(' column')) {
        // #guid column:1, #notetype column:2, #deck column:3, #tags column:6
        final n = int.tryParse(value.trim());
        if (n != null) skip.add(n - 1);
      }
    }
    pos = end + 1;
  }
  final body = pos >= text.length ? '' : text.substring(pos);
  final separator = sep ?? _guessSeparator(body);

  final cards = <ImportedCard>[];
  for (final row in parseDelimited(body, separator)) {
    final fields = <String>[];
    for (var i = 0; i < row.length; i++) {
      if (!skip.contains(i)) fields.add(row[i]);
    }
    final card = cardFromFields(fields);
    if (card != null) cards.add(card);
  }
  return cards;
}

String _separator(String value) {
  switch (value.trim().toLowerCase()) {
    case 'tab':
      return '\t';
    case 'comma':
      return ',';
    case 'semicolon':
      return ';';
    case 'space':
      return ' ';
    case 'pipe':
      return '|';
    case 'colon':
      return ':';
  }
  if (value.contains('\t') || value.trim().isEmpty) return '\t';
  return value.trim();
}

String _guessSeparator(String body) {
  final nl = body.indexOf('\n');
  final first = nl < 0 ? body : body.substring(0, nl);
  if (first.contains('\t')) return '\t';
  if (first.contains(';')) return ';';
  if (first.contains(',')) return ',';
  return '\t';
}

/// Découpe un texte délimité ; les champs entre guillemets peuvent contenir
/// le séparateur, des retours à la ligne et des guillemets doublés.
List<List<String>> parseDelimited(String text, String sep) {
  final rows = <List<String>>[];
  var row = <String>[];
  final sb = StringBuffer();
  var inQuotes = false;
  var fieldStart = true;
  var i = 0;
  final n = text.length;

  void endField() {
    row.add(sb.toString());
    sb.clear();
    fieldStart = true;
  }

  void endRow() {
    endField();
    if (!(row.length == 1 && row[0].isEmpty)) rows.add(row);
    row = <String>[];
  }

  while (i < n) {
    final ch = text[i];
    if (inQuotes) {
      if (ch == '"') {
        if (i + 1 < n && text[i + 1] == '"') {
          sb.write('"');
          i += 2;
          continue;
        }
        inQuotes = false;
        i++;
        continue;
      }
      sb.write(ch);
      i++;
      continue;
    }
    if (ch == '"' && fieldStart) {
      inQuotes = true;
      fieldStart = false;
      i++;
      continue;
    }
    if (text.startsWith(sep, i)) {
      endField();
      i += sep.length;
      continue;
    }
    if (ch == '\n') {
      endRow();
      i++;
      continue;
    }
    if (ch == '\r') {
      i++;
      continue;
    }
    sb.write(ch);
    fieldStart = false;
    i++;
  }
  if (sb.isNotEmpty || row.isNotEmpty) endRow();
  return rows;
}

// ------------------------------------------------------------- conversion

/// Convertit les champs d'une note en carte : 1er champ = recto,
/// 2e champ = verso. Les textes à trous deviennent question / réponse.
ImportedCard? cardFromFields(List<String> fields) {
  if (fields.isEmpty) return null;
  final first = fields[0];
  final second = fields.length > 1 ? fields[1] : '';
  var extra = 0;
  for (var i = 2; i < fields.length; i++) {
    if (cleanAnkiField(fields[i]).text.isNotEmpty) extra++;
  }

  if (hasCloze(first)) {
    final q = cleanAnkiField(clozeFront(first));
    final a = cleanAnkiField(clozeBack(first));
    final more = cleanAnkiField(second);
    final back = more.text.isEmpty ? a.text : '${a.text}\n${more.text}';
    return ImportedCard(
      front: q.text,
      back: back,
      hadMedia: q.hadMedia || more.hadMedia,
      wasCloze: true,
      extraFields: extra,
    );
  }

  final f = cleanAnkiField(first);
  final b = cleanAnkiField(second);
  if (f.text.isEmpty && b.text.isEmpty) return null;
  return ImportedCard(
    front: f.text,
    back: b.text,
    hadMedia: f.hadMedia || b.hadMedia,
    extraFields: extra,
  );
}
