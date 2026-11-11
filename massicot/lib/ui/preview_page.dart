import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';

import '../models.dart';
import '../pdf_export.dart';

/// Aperçu du PDF, avec les boutons natifs d'impression et de partage /
/// enregistrement.
class PreviewPage extends StatelessWidget {
  const PreviewPage({super.key, required this.deck});
  final Deck deck;

  String get _fileName {
    final safe = deck.name
        .replaceAll(RegExp(r'[\\/:*?"<>|]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    return '${safe.isEmpty ? 'flashcards' : safe}.pdf';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Aperçu avant impression')),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            color: cs.surfaceContainerHighest,
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
            child: Text(
              'À l\'impression : recto verso, retournement sur le bord '
              '${deck.flipShortEdge ? 'court' : 'long'}, échelle 100 % '
              '(« taille réelle », sans ajustement à la page).',
              style: theme.textTheme.bodySmall,
            ),
          ),
          Expanded(
            child: PdfPreview(
              build: (format) => buildDeckPdf(deck),
              initialPageFormat: PdfPageFormat.a4,
              canChangePageFormat: false,
              canChangeOrientation: false,
              canDebug: false,
              pdfFileName: _fileName,
            ),
          ),
        ],
      ),
    );
  }
}
