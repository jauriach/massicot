import 'package:flutter/material.dart';

import '../layout.dart';
import '../models.dart';
import 'common.dart';

/// Création ou réglages d'un paquet. Renvoie le paquet (créé ou modifié).
///
/// Le format (cartes par feuille) et la taille du texte déterminent ensemble
/// la limite de caractères : on choisit l'un, on voit l'autre.
class DeckFormPage extends StatefulWidget {
  const DeckFormPage({super.key, this.existing});
  final Deck? existing;

  @override
  State<DeckFormPage> createState() => _DeckFormPageState();
}

class _DeckFormPageState extends State<DeckFormPage> {
  late final TextEditingController _name;
  late final TextEditingController _keyword;
  late int _cols;
  late int _rows;
  late double _fontSize;
  late double _margin;
  late bool _flipShortEdge;
  late bool _cutLines;

  @override
  void initState() {
    super.initState();
    final d = widget.existing;
    _name = TextEditingController(text: d?.name ?? '');
    _keyword = TextEditingController(text: d?.keyword ?? '');
    _cols = d?.cols ?? 2;
    _rows = d?.rows ?? 4;
    _fontSize = d?.fontSize ?? 11;
    _margin = d?.marginMm ?? 0;
    _flipShortEdge = d?.flipShortEdge ?? false;
    _cutLines = d?.cutLines ?? true;
    _name.addListener(_refresh);
  }

  void _refresh() => setState(() {});

  @override
  void dispose() {
    _name.dispose();
    _keyword.dispose();
    super.dispose();
  }

  SheetLayout _layoutFor(CardFormat f) => SheetLayout(
        cols: f.cols,
        rows: f.rows,
        marginMm: _margin,
        fontSize: _fontSize,
      );

  SheetLayout get _layout => SheetLayout(
        cols: _cols,
        rows: _rows,
        marginMm: _margin,
        fontSize: _fontSize,
      );

  void _save() {
    final name = _name.text.trim();
    if (name.isEmpty) return;
    final existing = widget.existing;
    if (existing != null) {
      existing
        ..name = name
        ..keyword = _keyword.text.trim()
        ..cols = _cols
        ..rows = _rows
        ..fontSize = _fontSize
        ..marginMm = _margin
        ..flipShortEdge = _flipShortEdge
        ..cutLines = _cutLines;
      Navigator.pop(context, existing);
      return;
    }
    Navigator.pop(
      context,
      Deck(
        id: newId(),
        name: name,
        keyword: _keyword.text.trim(),
        cols: _cols,
        rows: _rows,
        fontSize: _fontSize,
        marginMm: _margin,
        flipShortEdge: _flipShortEdge,
        cutLines: _cutLines,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final existing = widget.existing;
    final limit = _layout.charLimit;
    final over = existing == null
        ? 0
        : existing.cards.where((c) => isOverLimit(c, limit)).length;

    return Scaffold(
      appBar: AppBar(
        title: Text(existing == null ? 'Nouveau paquet' : 'Réglages du paquet'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: FilledButton(
              onPressed: _name.text.trim().isEmpty ? null : _save,
              child: Text(existing == null ? 'Créer' : 'Enregistrer'),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
        child: ReadableWidth(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SectionTitle('Paquet'),
              TextField(
                controller: _name,
                autofocus: existing == null,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Nom du paquet',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _keyword,
                maxLength: 24,
                decoration: const InputDecoration(
                  labelText: 'Mot-clé (facultatif)',
                  helperText:
                      'Imprimé en haut à gauche de chaque carte, au recto '
                      'et au verso.',
                  helperMaxLines: 2,
                  border: OutlineInputBorder(),
                ),
              ),
              const SectionTitle('Format des cartes'),
              Text(
                'Le nombre de cartes par feuille A4 fixe la taille de chaque '
                'carte, donc la longueur de texte autorisée par face.',
                style: theme.textTheme.bodyMedium
                    ?.copyWith(color: cs.onSurfaceVariant),
              ),
              const SizedBox(height: 14),
              SegmentedButton<double>(
                showSelectedIcon: false,
                segments: const [
                  ButtonSegment(value: 9, label: Text('Petit texte')),
                  ButtonSegment(value: 11, label: Text('Moyen')),
                  ButtonSegment(value: 13, label: Text('Grand')),
                ],
                selected: {_fontSize},
                onSelectionChanged: (s) => setState(() => _fontSize = s.first),
              ),
              const SizedBox(height: 14),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 96,
                    child: _SheetDiagram(cols: _cols, rows: _rows),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      children: [
                        for (final f in cardFormats)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 6),
                            child: _FormatTile(
                              selected: f.cols == _cols && f.rows == _rows,
                              title: '${f.perPage} cartes par feuille',
                              subtitle:
                                  '${fmtMm(_layoutFor(f).cardWidthMm)} × '
                                  '${fmtMm(_layoutFor(f).cardHeightMm)} mm · '
                                  '${_layoutFor(f).charLimit} caractères max',
                              onTap: () => setState(() {
                                _cols = f.cols;
                                _rows = f.rows;
                              }),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: cs.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  'Limite de ce paquet : $limit caractères par face.',
                  style: theme.textTheme.titleSmall,
                ),
              ),
              if (over > 0) ...[
                const SizedBox(height: 10),
                Text(
                  '${plural(over, 'carte existante dépasse', 'cartes existantes dépassent')} '
                  'cette limite. Leur texte sera réduit à l\'impression tant '
                  'qu\'elles ne sont pas raccourcies.',
                  style: theme.textTheme.bodySmall?.copyWith(color: cs.error),
                ),
              ],
              const SectionTitle('Impression'),
              Text('Marge autour de la planche',
                  style: theme.textTheme.bodyMedium),
              const SizedBox(height: 8),
              SegmentedButton<double>(
                showSelectedIcon: false,
                segments: const [
                  ButtonSegment(value: 0, label: Text('Aucune')),
                  ButtonSegment(value: 5, label: Text('5 mm')),
                  ButtonSegment(value: 10, label: Text('10 mm')),
                ],
                selected: {_margin},
                onSelectionChanged: (s) => setState(() => _margin = s.first),
              ),
              const SizedBox(height: 6),
              Text(
                _margin == 0
                    ? 'Les bords de la feuille servent de bords de cartes : '
                        'moins de coupes.'
                    : 'Une chute de ${fmtMm(_margin)} mm est à retirer sur les '
                        'quatre côtés.',
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: cs.onSurfaceVariant),
              ),
              const SizedBox(height: 18),
              Text('Retournement recto verso',
                  style: theme.textTheme.bodyMedium),
              const SizedBox(height: 8),
              SegmentedButton<bool>(
                showSelectedIcon: false,
                segments: const [
                  ButtonSegment(value: false, label: Text('Bord long')),
                  ButtonSegment(value: true, label: Text('Bord court')),
                ],
                selected: {_flipShortEdge},
                onSelectionChanged: (s) =>
                    setState(() => _flipShortEdge = s.first),
              ),
              const SizedBox(height: 6),
              Text(
                'Doit correspondre au réglage choisi dans la fenêtre '
                'd\'impression. « Bord long » est le réglage habituel.',
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: cs.onSurfaceVariant),
              ),
              const SizedBox(height: 8),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Traits de coupe'),
                subtitle: const Text('Filets gris fins, au recto seulement.'),
                value: _cutLines,
                onChanged: (v) => setState(() => _cutLines = v),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FormatTile extends StatelessWidget {
  const _FormatTile({
    required this.selected,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final bool selected;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Material(
      color: selected ? cs.secondaryContainer : Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: selected ? cs.secondary : cs.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: theme.textTheme.bodyLarge),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: cs.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              if (selected) Icon(Icons.check, size: 20, color: cs.secondary),
            ],
          ),
        ),
      ),
    );
  }
}

/// Miniature de la feuille A4 découpée.
class _SheetDiagram extends StatelessWidget {
  const _SheetDiagram({required this.cols, required this.rows});
  final int cols;
  final int rows;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return AspectRatio(
      aspectRatio: a4WidthMm / a4HeightMm,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: cs.outline),
        ),
        child: Column(
          children: [
            for (var r = 0; r < rows; r++)
              Expanded(
                child: Row(
                  children: [
                    for (var c = 0; c < cols; c++)
                      Expanded(
                        child: Container(
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: cs.outlineVariant,
                              width: 0.5,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
