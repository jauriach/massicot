import 'package:flutter_test/flutter_test.dart';
import 'package:massicot/layout.dart';

void main() {
  group('correspondance recto verso', () {
    for (final f in cardFormats) {
      for (final margin in pageMargins) {
        final l = SheetLayout(cols: f.cols, rows: f.rows, marginMm: margin);

        test('${f.perPage} cartes, marge $margin : bord long', () {
          final seen = <int>{};
          for (var slot = 0; slot < l.perPage; slot++) {
            final back = l.backSlot(slot, flipShortEdge: false);
            seen.add(back);
            // Feuille retournée autour de son axe vertical : x -> 210 - x.
            final frontLeft = l.slotLeftMm(slot);
            final backRight = l.slotLeftMm(back) + l.cardWidthMm;
            expect(backRight, closeTo(a4WidthMm - frontLeft, 1e-9));
            expect(l.slotTopMm(back), closeTo(l.slotTopMm(slot), 1e-9));
          }
          expect(seen.length, l.perPage);
        });

        test('${f.perPage} cartes, marge $margin : bord court', () {
          final seen = <int>{};
          for (var slot = 0; slot < l.perPage; slot++) {
            final back = l.backSlot(slot, flipShortEdge: true);
            seen.add(back);
            // Feuille retournée autour de son axe horizontal : y -> 297 - y.
            final frontTop = l.slotTopMm(slot);
            final backBottom = l.slotTopMm(back) + l.cardHeightMm;
            expect(backBottom, closeTo(a4HeightMm - frontTop, 1e-9));
            expect(l.slotLeftMm(back), closeTo(l.slotLeftMm(slot), 1e-9));
          }
          expect(seen.length, l.perPage);
        });
      }
    }
  });

  test('la planche remplit exactement la zone utile', () {
    const l = SheetLayout(cols: 2, rows: 4, marginMm: 5);
    expect(l.cardWidthMm * 2 + 10, closeTo(a4WidthMm, 1e-9));
    expect(l.cardHeightMm * 4 + 10, closeTo(a4HeightMm, 1e-9));
  });

  test('plus de cartes par feuille = moins de caractères', () {
    for (final size in fontSizes) {
      var previous = 1 << 30;
      for (final f in cardFormats) {
        final limit =
            SheetLayout(cols: f.cols, rows: f.rows, fontSize: size).charLimit;
        expect(limit, lessThanOrEqualTo(previous));
        expect(limit, greaterThanOrEqualTo(10));
        previous = limit;
      }
    }
  });

  test('texte plus grand = moins de caractères', () {
    for (final f in cardFormats) {
      final small =
          SheetLayout(cols: f.cols, rows: f.rows, fontSize: 9).charLimit;
      final large =
          SheetLayout(cols: f.cols, rows: f.rows, fontSize: 13).charLimit;
      expect(large, lessThan(small));
    }
  });

  test('nombre de feuilles', () {
    const l = SheetLayout(cols: 2, rows: 4);
    expect(l.sheetCount(0), 0);
    expect(l.sheetCount(8), 1);
    expect(l.sheetCount(9), 2);
  });
}
