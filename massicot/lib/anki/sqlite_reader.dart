import 'dart:convert';
import 'dart:typed_data';

/// Lecteur SQLite minimal, en Dart pur et en lecture seule.
///
/// Il sait parcourir une table (B-arbre de table, pages de débordement
/// comprises), ce qui suffit pour lire la table `notes` d'un paquet Anki sans
/// embarquer de bibliothèque native.
class SqliteFormatException implements Exception {
  SqliteFormatException(this.message);
  final String message;
  @override
  String toString() => message;
}

class _Cursor {
  _Cursor(this.b, this.p);
  final Uint8List b;
  int p;

  int varint() {
    var v = 0;
    for (var i = 0; i < 8; i++) {
      final byte = b[p++];
      v = (v << 7) | (byte & 0x7f);
      if ((byte & 0x80) == 0) return v;
    }
    return (v << 8) | b[p++];
  }
}

class SqliteReader {
  SqliteReader(this._d) {
    const magic = 'SQLite format 3';
    if (_d.length < 100) {
      throw SqliteFormatException('Fichier trop court.');
    }
    for (var i = 0; i < magic.length; i++) {
      if (_d[i] != magic.codeUnitAt(i)) {
        throw SqliteFormatException('Ce fichier n\'est pas une base SQLite.');
      }
    }
    final ps = _u16(16);
    _pageSize = ps == 1 ? 65536 : ps;
    _usable = _pageSize - _d[20];
    if (_pageSize < 512 || _usable < 480) {
      throw SqliteFormatException('En-tête SQLite invalide.');
    }
  }

  final Uint8List _d;
  late final int _pageSize;
  late final int _usable;

  int _u16(int o) => (_d[o] << 8) | _d[o + 1];
  int _u32(int o) =>
      (_d[o] << 24) | (_d[o + 1] << 16) | (_d[o + 2] << 8) | _d[o + 3];

  /// Noms des colonnes d'une table, dans l'ordre, d'après son `CREATE TABLE`.
  List<String> columns(String table) {
    final sql = _masterRow(table)?[4];
    if (sql is! String) return const [];
    final open = sql.indexOf('(');
    final close = sql.lastIndexOf(')');
    if (open < 0 || close <= open) return const [];
    const constraints = {
      'primary', 'unique', 'check', 'foreign', 'constraint', //
    };
    final names = <String>[];
    var depth = 0;
    final part = StringBuffer();
    void flush() {
      final def = part.toString().trim();
      part.clear();
      if (def.isEmpty) return;
      final first = def.split(RegExp(r'\s+')).first;
      final name = first.replaceAll(RegExp('["`\\[\\]\']'), '');
      if (!constraints.contains(name.toLowerCase())) names.add(name);
    }

    for (var i = open + 1; i < close; i++) {
      final ch = sql[i];
      if (ch == '(') depth++;
      if (ch == ')') depth--;
      if (ch == ',' && depth == 0) {
        flush();
      } else {
        part.write(ch);
      }
    }
    flush();
    return names;
  }

  /// Toutes les lignes d'une table. Chaque valeur est `null`, `int`,
  /// `double`, `String` ou `Uint8List`.
  List<List<Object?>> readTable(String table) {
    final row = _masterRow(table);
    if (row == null) {
      throw SqliteFormatException('Table « $table » introuvable.');
    }
    final root = row[3];
    if (root is! int || root < 1) {
      throw SqliteFormatException('Table « $table » illisible.');
    }
    final out = <List<Object?>>[];
    _walk(root, out, 0);
    return out;
  }

  List<Object?>? _masterRow(String table) {
    final master = <List<Object?>>[];
    _walk(1, master, 0);
    for (final r in master) {
      if (r.length >= 5 && r[0] == 'table' && r[1] == table) return r;
    }
    return null;
  }

  void _walk(int pageNo, List<List<Object?>> out, int depth) {
    if (depth > 64 || pageNo < 1) return;
    final base = (pageNo - 1) * _pageSize;
    if (base + _pageSize > _d.length) return;
    final h = base + (pageNo == 1 ? 100 : 0);
    final type = _d[h];
    final cells = _u16(h + 3);
    if (type == 0x0d) {
      for (var i = 0; i < cells; i++) {
        final cell = base + _u16(h + 8 + 2 * i);
        final c = _Cursor(_d, cell);
        final payloadLen = c.varint();
        c.varint(); // rowid
        out.add(_record(_payload(c.p, payloadLen)));
      }
    } else if (type == 0x05) {
      for (var i = 0; i < cells; i++) {
        final cell = base + _u16(h + 12 + 2 * i);
        _walk(_u32(cell), out, depth + 1);
      }
      _walk(_u32(h + 8), out, depth + 1);
    }
  }

  Uint8List _payload(int start, int len) {
    final x = _usable - 35;
    if (len <= x) return Uint8List.sublistView(_d, start, start + len);
    final m = ((_usable - 12) * 32 ~/ 255) - 23;
    final k = m + ((len - m) % (_usable - 4));
    final local = k <= x ? k : m;
    final out = Uint8List(len);
    out.setRange(0, local, _d, start);
    var filled = local;
    var next = _u32(start + local);
    while (next != 0 && filled < len) {
      final b = (next - 1) * _pageSize;
      if (b < 0 || b + _pageSize > _d.length) break;
      final remaining = len - filled;
      final take = remaining < _usable - 4 ? remaining : _usable - 4;
      out.setRange(filled, filled + take, _d, b + 4);
      filled += take;
      next = _u32(b);
    }
    return out;
  }

  List<Object?> _record(Uint8List p) {
    final c = _Cursor(p, 0);
    final headerLen = c.varint();
    final types = <int>[];
    while (c.p < headerLen) {
      types.add(c.varint());
    }
    var o = headerLen;
    final row = <Object?>[];
    const sizes = [0, 1, 2, 3, 4, 6, 8];
    for (final t in types) {
      if (t == 0) {
        row.add(null);
      } else if (t >= 1 && t <= 6) {
        final n = sizes[t];
        var v = 0;
        for (var i = 0; i < n; i++) {
          v = (v << 8) | p[o + i];
        }
        final bits = n * 8;
        if (bits < 64 && (v & (1 << (bits - 1))) != 0) v -= 1 << bits;
        row.add(v);
        o += n;
      } else if (t == 7) {
        row.add(ByteData.sublistView(p, o, o + 8).getFloat64(0));
        o += 8;
      } else if (t == 8) {
        row.add(0);
      } else if (t == 9) {
        row.add(1);
      } else if (t >= 12) {
        final n = (t - 12) ~/ 2;
        final bytes = Uint8List.sublistView(p, o, o + n);
        row.add(t.isEven ? bytes : utf8.decode(bytes, allowMalformed: true));
        o += n;
      } else {
        row.add(null);
      }
    }
    return row;
  }
}
