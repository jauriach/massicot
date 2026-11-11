import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import 'layout.dart';
import 'models.dart';

const double _mm = PdfPageFormat.mm;

/// Construit le PDF A4 : pour chaque feuille, une page recto puis une page
/// verso. Le verso est disposé en miroir pour que chaque carte retrouve son
/// dos après retournement de la feuille.
Future<Uint8List> buildDeckPdf(Deck deck) async {
  final regular =
      pw.Font.ttf(await rootBundle.load('assets/fonts/DejaVuSans.ttf'));
  final bold =
      pw.Font.ttf(await rootBundle.load('assets/fonts/DejaVuSans-Bold.ttf'));
  final layout = deck.layout;
  final per = layout.perPage;
  final doc = pw.Document(title: deck.name, creator: 'Massicot');

  for (var start = 0; start < deck.cards.length; start += per) {
    final end =
        start + per > deck.cards.length ? deck.cards.length : start + per;
    final slice = deck.cards.sublist(start, end);
    for (final front in const [true, false]) {
      doc.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: pw.EdgeInsets.zero,
          build: (context) => _sheet(deck, layout, slice, front, regular, bold),
        ),
      );
    }
  }
  if (deck.cards.isEmpty) {
    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (context) => pw.SizedBox(),
      ),
    );
  }
  return doc.save();
}

pw.Widget _sheet(
  Deck deck,
  SheetLayout l,
  List<Flashcard> cards,
  bool front,
  pw.Font regular,
  pw.Font bold,
) {
  final children = <pw.Widget>[];
  for (var i = 0; i < cards.length; i++) {
    final slot = front ? i : l.backSlot(i, flipShortEdge: deck.flipShortEdge);
    children.add(
      pw.Positioned(
        left: l.slotLeftMm(slot) * _mm,
        top: l.slotTopMm(slot) * _mm,
        child: _card(
          l,
          front ? cards[i].front : cards[i].back,
          deck.keyword.trim(),
          front ? bold : regular,
          bold,
        ),
      ),
    );
  }
  // Traits de coupe au recto seulement : au verso, le moindre décalage de
  // l'imprimante les rendrait visibles sur les cartes.
  if (front && deck.cutLines) children.addAll(_cutLines(l));

  return pw.SizedBox(
    width: a4WidthMm * _mm,
    height: a4HeightMm * _mm,
    child: pw.Stack(children: children),
  );
}

List<pw.Widget> _cutLines(SheetLayout l) {
  const thickness = 0.3;
  final lines = <pw.Widget>[];
  final outer = l.marginMm > 0;
  for (var c = outer ? 0 : 1; c <= (outer ? l.cols : l.cols - 1); c++) {
    final x = (l.marginMm + c * l.cardWidthMm) * _mm;
    lines.add(
      pw.Positioned(
        left: x - thickness / 2,
        top: 0,
        child: pw.Container(
          width: thickness,
          height: a4HeightMm * _mm,
          color: PdfColors.grey500,
        ),
      ),
    );
  }
  for (var r = outer ? 0 : 1; r <= (outer ? l.rows : l.rows - 1); r++) {
    final y = (l.marginMm + r * l.cardHeightMm) * _mm;
    lines.add(
      pw.Positioned(
        left: 0,
        top: y - thickness / 2,
        child: pw.Container(
          width: a4WidthMm * _mm,
          height: thickness,
          color: PdfColors.grey500,
        ),
      ),
    );
  }
  return lines;
}

pw.Widget _card(
  SheetLayout l,
  String text,
  String keyword,
  pw.Font textFont,
  pw.Font keywordFont,
) {
  final textWidth = l.textWidthMm * _mm;
  final textHeight = l.textHeightMm * _mm;
  return pw.SizedBox(
    width: l.cardWidthMm * _mm,
    height: l.cardHeightMm * _mm,
    child: pw.Stack(
      children: [
        pw.Positioned(
          left: cardPadMm * _mm,
          top: (cardPadMm + cardBandMm) * _mm,
          child: pw.SizedBox(
            width: textWidth,
            height: textHeight,
            // Filet de sécurité : un texte qui dépasserait malgré la limite
            // est réduit, jamais coupé ni débordant sur la carte voisine.
            child: pw.FittedBox(
              fit: pw.BoxFit.scaleDown,
              alignment: pw.Alignment.center,
              child: pw.SizedBox(
                width: textWidth,
                child: pw.Text(
                  text.trim(),
                  textAlign: pw.TextAlign.center,
                  style: pw.TextStyle(
                    font: textFont,
                    fontSize: l.fontSize,
                    lineSpacing: 1.5,
                    color: PdfColors.black,
                  ),
                ),
              ),
            ),
          ),
        ),
        if (keyword.isNotEmpty)
          pw.Positioned(
            left: cardPadMm * _mm,
            top: (cardPadMm - 1.5) * _mm,
            child: pw.Text(
              keyword.toUpperCase(),
              style: pw.TextStyle(
                font: keywordFont,
                fontSize: 6.5,
                letterSpacing: 0.8,
                color: PdfColors.grey700,
              ),
            ),
          ),
      ],
    ),
  );
}
