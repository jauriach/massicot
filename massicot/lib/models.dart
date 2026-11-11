import 'layout.dart';

int _seq = 0;
String newId() => '${DateTime.now().microsecondsSinceEpoch}-${_seq++}';

class Flashcard {
  Flashcard({required this.id, required this.front, required this.back});

  final String id;
  String front;
  String back;

  factory Flashcard.fromJson(Map<String, dynamic> j) => Flashcard(
        id: (j['id'] as String?) ?? newId(),
        front: (j['front'] as String?) ?? '',
        back: (j['back'] as String?) ?? '',
      );

  Map<String, dynamic> toJson() => {'id': id, 'front': front, 'back': back};
}

class Deck {
  Deck({
    required this.id,
    required this.name,
    this.keyword = '',
    this.cols = 2,
    this.rows = 4,
    this.fontSize = 11,
    this.marginMm = 0,
    this.flipShortEdge = false,
    this.cutLines = true,
    List<Flashcard>? cards,
  }) : cards = cards ?? <Flashcard>[];

  final String id;
  String name;

  /// Mot-clé imprimé en haut à gauche du recto et du verso (vide = aucun).
  String keyword;
  int cols;
  int rows;
  double fontSize;
  double marginMm;
  bool flipShortEdge;
  bool cutLines;
  final List<Flashcard> cards;

  SheetLayout get layout => SheetLayout(
        cols: cols,
        rows: rows,
        marginMm: marginMm,
        fontSize: fontSize,
      );

  int get charLimit => layout.charLimit;

  factory Deck.fromJson(Map<String, dynamic> j) => Deck(
        id: (j['id'] as String?) ?? newId(),
        name: (j['name'] as String?) ?? 'Sans nom',
        keyword: (j['keyword'] as String?) ?? '',
        cols: (j['cols'] as num?)?.toInt() ?? 2,
        rows: (j['rows'] as num?)?.toInt() ?? 4,
        fontSize: (j['fontSize'] as num?)?.toDouble() ?? 11,
        marginMm: (j['marginMm'] as num?)?.toDouble() ?? 0,
        flipShortEdge: (j['flipShortEdge'] as bool?) ?? false,
        cutLines: (j['cutLines'] as bool?) ?? true,
        cards: ((j['cards'] as List?) ?? const [])
            .map((e) => Flashcard.fromJson(e as Map<String, dynamic>))
            .toList(),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'keyword': keyword,
        'cols': cols,
        'rows': rows,
        'fontSize': fontSize,
        'marginMm': marginMm,
        'flipShortEdge': flipShortEdge,
        'cutLines': cutLines,
        'cards': cards.map((c) => c.toJson()).toList(),
      };
}
