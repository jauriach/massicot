/// Géométrie de la planche A4 et limite de texte.
///
/// Tout est exprimé en millimètres. Ce fichier ne dépend pas de Flutter :
/// il sert à la fois à l'interface, à l'import et au PDF, pour que la limite
/// affichée soit exactement celle qui est imprimée.
library;

const double a4WidthMm = 210;
const double a4HeightMm = 297;
const double ptPerMm = 72 / 25.4;

/// Marge intérieure de chaque carte (protège du massicot et du décalage
/// recto verso de l'imprimante).
const double cardPadMm = 6;

/// Bandeau réservé en haut (mot-clé) et, par symétrie, en bas.
const double cardBandMm = 4;

class CardFormat {
  const CardFormat(this.cols, this.rows);
  final int cols;
  final int rows;
  int get perPage => cols * rows;
}

/// Formats proposés, du plus grand au plus petit.
const List<CardFormat> cardFormats = [
  CardFormat(1, 2), // 2  — A5
  CardFormat(2, 2), // 4  — A6
  CardFormat(2, 3), // 6
  CardFormat(2, 4), // 8  — A7
  CardFormat(3, 3), // 9
  CardFormat(2, 5), // 10
  CardFormat(3, 4), // 12
  CardFormat(4, 4), // 16 — A8
  CardFormat(4, 5), // 20
];

const List<double> fontSizes = [9, 11, 13];
const List<double> pageMargins = [0, 5, 10];

class SheetLayout {
  const SheetLayout({
    required this.cols,
    required this.rows,
    this.marginMm = 0,
    this.fontSize = 11,
  });

  final int cols;
  final int rows;
  final double marginMm;
  final double fontSize;

  int get perPage => cols * rows;

  double get cardWidthMm => (a4WidthMm - 2 * marginMm) / cols;
  double get cardHeightMm => (a4HeightMm - 2 * marginMm) / rows;

  double get textWidthMm => cardWidthMm - 2 * cardPadMm;
  double get textHeightMm => cardHeightMm - 2 * (cardPadMm + cardBandMm);

  /// Nombre maximal de caractères par face.
  ///
  /// Estimation prudente : largeur moyenne d'un caractère = 0,55 corps,
  /// interligne = 1,25 corps, et 30 % de perte pour les retours à la ligne.
  int get charLimit {
    final perLine = (textWidthMm * ptPerMm / (fontSize * 0.55)).floor();
    final lines = (textHeightMm * ptPerMm / (fontSize * 1.25)).floor();
    final raw = (perLine * lines * 0.7).floor();
    final rounded = raw >= 100 ? raw - raw % 10 : raw - raw % 5;
    return rounded < 10 ? 10 : rounded;
  }

  int rowOf(int slot) => slot ~/ cols;
  int colOf(int slot) => slot % cols;

  double slotLeftMm(int slot) => marginMm + colOf(slot) * cardWidthMm;
  double slotTopMm(int slot) => marginMm + rowOf(slot) * cardHeightMm;

  /// Emplacement, sur la page verso, de la carte placée en [slot] au recto.
  ///
  /// Retournement sur le bord long (standard en portrait) : la feuille tourne
  /// autour de son axe vertical, les colonnes sont inversées.
  /// Retournement sur le bord court : les rangées sont inversées.
  int backSlot(int slot, {required bool flipShortEdge}) {
    final r = rowOf(slot);
    final c = colOf(slot);
    return flipShortEdge
        ? (rows - 1 - r) * cols + c
        : r * cols + (cols - 1 - c);
  }

  int sheetCount(int cards) => cards <= 0 ? 0 : ((cards - 1) ~/ perPage) + 1;
}
