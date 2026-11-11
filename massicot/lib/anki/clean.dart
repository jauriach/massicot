/// Nettoyage par expressions régulières des champs Anki / AnkiMobile :
/// HTML, sons, images, LaTeX, textes à trous, entités.
library;

class Cleaned {
  const Cleaned(this.text, {this.hadMedia = false});
  final String text;

  /// Vrai si une image, un son ou une vidéo a été retiré.
  final bool hadMedia;
}

final RegExp _reStyle = RegExp(
  r'<(style|script)\b[^>]*>.*?</\1\s*>',
  caseSensitive: false,
  dotAll: true,
);
final RegExp _reComment = RegExp(r'<!--.*?-->', dotAll: true);
final RegExp _reSound = RegExp(r'\[sound:[^\]]*\]', caseSensitive: false);
final RegExp _reMediaTag = RegExp(
  r'<(img|audio|video|object|embed|iframe|source)\b[^>]*>',
  caseSensitive: false,
);
final RegExp _reAnkiTag = RegExp(r'\[/?anki:[^\]]*\]', caseSensitive: false);
final RegExp _reLatex = RegExp(r'\[/?(latex|\$\$?)\]', caseSensitive: false);
final RegExp _reMathJax = RegExp(r'\\[()\[\]]');
final RegExp _reBr = RegExp(r'<br\s*/?>', caseSensitive: false);
final RegExp _reBlock = RegExp(
  r'</?(div|p|tr|h[1-6]|blockquote|ul|ol|table|hr)\b[^>]*>',
  caseSensitive: false,
);
final RegExp _reLiOpen = RegExp(r'<li\b[^>]*>', caseSensitive: false);
final RegExp _reLiClose = RegExp(r'</li\s*>', caseSensitive: false);
final RegExp _reCell = RegExp(r'</t[dh]\s*>', caseSensitive: false);
final RegExp _reTag = RegExp(r'</?[a-zA-Z][^>]*>');
final RegExp _reTemplate = RegExp(r'\{\{[^{}]*\}\}');
final RegExp _reEntity = RegExp(r'&(#[xX]?[0-9a-fA-F]+|[a-zA-Z]+);');
final RegExp _reSpaces = RegExp(r'[ \t\u00A0]+');
final RegExp _reNewlines = RegExp(r'\n{2,}');
final RegExp _reCloze = RegExp(
  r'\{\{c\d+::(.*?)(?:::(.*?))?\}\}',
  dotAll: true,
);

const Map<String, String> _entities = {
  'nbsp': ' ',
  'amp': '&',
  'lt': '<',
  'gt': '>',
  'quot': '"',
  'apos': "'",
  'laquo': '«',
  'raquo': '»',
  'hellip': '…',
  'ndash': '–',
  'mdash': '—',
  'lsquo': '‘',
  'rsquo': '’',
  'ldquo': '“',
  'rdquo': '”',
  'euro': '€',
  'deg': '°',
  'times': '×',
  'rarr': '→',
  'larr': '←',
  'eacute': 'é',
  'egrave': 'è',
  'ecirc': 'ê',
  'agrave': 'à',
  'acirc': 'â',
  'ccedil': 'ç',
  'ocirc': 'ô',
  'ucirc': 'û',
  'ugrave': 'ù',
  'icirc': 'î',
  'iuml': 'ï',
  'oelig': 'œ',
};

String _decodeEntities(String s) {
  return s.replaceAllMapped(_reEntity, (m) {
    final body = m.group(1)!;
    if (body.startsWith('#')) {
      final hex = body.length > 1 && (body[1] == 'x' || body[1] == 'X');
      final code = int.tryParse(
        hex ? body.substring(2) : body.substring(1),
        radix: hex ? 16 : 10,
      );
      if (code == null || code <= 0 || code > 0x10FFFF) return m.group(0)!;
      return String.fromCharCode(code);
    }
    return _entities[body.toLowerCase()] ?? m.group(0)!;
  });
}

bool hasCloze(String raw) => _reCloze.hasMatch(raw);

/// Texte à trous, côté question : `{{c1::Paris::ville}}` devient `[ville]`,
/// `{{c1::Paris}}` devient `[…]`.
String clozeFront(String raw) => raw.replaceAllMapped(_reCloze, (m) {
      final hint = m.group(2) ?? '';
      return hint.isEmpty ? '[…]' : '[$hint]';
    });

/// Texte à trous, côté réponse : les trous sont remplis.
String clozeBack(String raw) =>
    raw.replaceAllMapped(_reCloze, (m) => m.group(1) ?? '');

/// Retire tout ce qui est propre à Anki et renvoie du texte brut.
Cleaned cleanAnkiField(String raw) {
  var s = raw.replaceAll('\r', '');
  s = s.replaceAll(_reStyle, '').replaceAll(_reComment, '');

  final hadMedia = _reSound.hasMatch(s) || _reMediaTag.hasMatch(s);
  s = s.replaceAll(_reSound, '').replaceAll(_reMediaTag, '');
  s = s.replaceAll(_reAnkiTag, '');
  s = s.replaceAll(_reLatex, '').replaceAll(_reMathJax, '');

  s = s.replaceAll(_reBr, '\n');
  s = s.replaceAll(_reLiOpen, '\n• ').replaceAll(_reLiClose, '\n');
  s = s.replaceAll(_reCell, ' ');
  s = s.replaceAll(_reBlock, '\n');
  s = s.replaceAll(_reTag, '');
  s = s.replaceAll(_reTemplate, '');
  s = _decodeEntities(s);

  s = s.replaceAll(_reSpaces, ' ');
  s = s.split('\n').map((l) => l.trim()).join('\n');
  s = s.replaceAll(_reNewlines, '\n').trim();
  return Cleaned(s, hadMedia: hadMedia);
}
