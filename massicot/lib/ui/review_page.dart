import 'package:flutter/material.dart';

import '../anki/importer.dart';
import '../models.dart';
import 'common.dart';

enum _Status { pending, kept, skipped }

class _Item {
  _Item(this.src)
      : front = src.front,
        back = src.back;

  final ImportedCard src;
  String front;
  String back;
  _Status status = _Status.pending;
}

enum _Phase { summary, review, done }

/// Revue d'un import Anki, carte par carte.
///
/// Les cartes conformes sont acceptées d'office. Celles qui posent problème
/// (face trop longue, face vide, image ou son retiré) sont présentées une à
/// une : on corrige, on raccourcit, on ignore ou on valide.
/// Renvoie la liste des cartes à ajouter au paquet.
class ReviewPage extends StatefulWidget {
  const ReviewPage({
    super.key,
    required this.deck,
    required this.imported,
    required this.sourceName,
  });

  final Deck deck;
  final List<ImportedCard> imported;
  final String sourceName;

  @override
  State<ReviewPage> createState() => _ReviewPageState();
}

class _ReviewPageState extends State<ReviewPage> {
  late final List<_Item> _items;
  late final int _limit;
  final TextEditingController _front = TextEditingController();
  final TextEditingController _back = TextEditingController();

  _Phase _phase = _Phase.summary;
  bool _reviewAll = false;
  List<int> _queue = <int>[];
  int _pos = 0;

  @override
  void initState() {
    super.initState();
    _limit = widget.deck.charLimit;
    _items = widget.imported.map(_Item.new).toList();
    _front.addListener(_refresh);
    _back.addListener(_refresh);
  }

  void _refresh() => setState(() {});

  @override
  void dispose() {
    _front.dispose();
    _back.dispose();
    super.dispose();
  }

  // ------------------------------------------------------------ diagnostic

  List<String> _problems(String front, String back, ImportedCard src) {
    final list = <String>[];
    if (front.trim().isEmpty) list.add('Recto vide');
    if (back.trim().isEmpty) list.add('Verso vide');
    if (textLength(front) > _limit) list.add('Recto trop long');
    if (textLength(back) > _limit) list.add('Verso trop long');
    if (src.hadMedia) list.add('Image ou son retiré');
    return list;
  }

  bool _fits(String front, String back) =>
      front.trim().isNotEmpty &&
      back.trim().isNotEmpty &&
      textLength(front) <= _limit &&
      textLength(back) <= _limit;

  bool _needsReview(_Item it) =>
      !_fits(it.front, it.back) || it.src.hadMedia;

  int get _toReviewCount => _items.where(_needsReview).length;

  // ------------------------------------------------------------ navigation

  void _start() {
    final queue = <int>[];
    for (var i = 0; i < _items.length; i++) {
      if (_reviewAll || _needsReview(_items[i])) queue.add(i);
    }
    setState(() {
      _queue = queue;
      _pos = 0;
      _phase = queue.isEmpty ? _Phase.done : _Phase.review;
    });
    if (queue.isNotEmpty) _load();
  }

  _Item get _current => _items[_queue[_pos]];

  void _load() {
    _front.text = _current.front;
    _back.text = _current.back;
  }

  void _store() {
    _current
      ..front = _front.text
      ..back = _back.text;
  }

  void _decide(_Status status) {
    _store();
    _current.status = status;
    if (_pos + 1 >= _queue.length) {
      setState(() => _phase = _Phase.done);
      return;
    }
    setState(() => _pos++);
    _load();
  }

  void _previous() {
    if (_pos == 0) return;
    _store();
    setState(() => _pos--);
    _load();
  }

  List<Flashcard> _result() {
    final reviewed = _queue.toSet();
    final out = <Flashcard>[];
    for (var i = 0; i < _items.length; i++) {
      final it = _items[i];
      final keep = reviewed.contains(i)
          ? it.status == _Status.kept
          : _fits(it.front, it.back);
      if (keep) {
        out.add(
          Flashcard(
            id: newId(),
            front: it.front.trim(),
            back: it.back.trim(),
          ),
        );
      }
    }
    return out;
  }

  // ------------------------------------------------------------------- UI

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Annuler l\'import',
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Import Anki'),
            Text(
              widget.sourceName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
      body: switch (_phase) {
        _Phase.summary => _buildSummary(context),
        _Phase.review => _buildReview(context),
        _Phase.done => _buildDone(context),
      },
    );
  }

  Widget _buildSummary(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final total = _items.length;
    final toReview = _toReviewCount;
    final ok = total - toReview;
    final queued = _reviewAll ? total : toReview;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 40),
      child: ReadableWidth(
        maxWidth: 520,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '${plural(total, 'carte lue', 'cartes lues')}',
              style: theme.textTheme.headlineSmall,
            ),
            const SizedBox(height: 6),
            Text(
              'Balises HTML, sons, images et marqueurs Anki ont été retirés. '
              'Limite du paquet : $_limit caractères par face.',
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: cs.onSurfaceVariant),
            ),
            const SizedBox(height: 20),
            _StatRow(
              icon: Icons.check_circle_outline,
              color: cs.primary,
              label: plural(ok, 'carte conforme', 'cartes conformes'),
              detail: 'Ajoutées sans intervention.',
            ),
            const SizedBox(height: 10),
            _StatRow(
              icon: Icons.error_outline,
              color: toReview > 0 ? cs.error : cs.outline,
              label: plural(toReview, 'carte à revoir', 'cartes à revoir'),
              detail: 'Trop longues, incomplètes ou privées d\'une image.',
            ),
            const SizedBox(height: 12),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Revoir aussi les cartes conformes'),
              value: _reviewAll,
              onChanged: (v) => setState(() => _reviewAll = v),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _start,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Text(
                  queued == 0
                      ? 'Continuer'
                      : 'Revoir ${plural(queued, 'carte', 'cartes')}',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReview(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final item = _current;
    final problems = _problems(_front.text, _back.text, item.src);
    final valid = _fits(_front.text, _back.text);

    return Column(
      children: [
        LinearProgressIndicator(value: _pos / _queue.length),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            child: ReadableWidth(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Carte ${_pos + 1} sur ${_queue.length}',
                    style: theme.textTheme.titleMedium,
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      if (problems.isEmpty)
                        _Tag(text: 'Conforme', color: cs.primary),
                      for (final p in problems) _Tag(text: p, color: cs.error),
                      if (item.src.wasCloze)
                        _Tag(text: 'Texte à trous converti', color: cs.outline),
                      if (item.src.extraFields > 0)
                        _Tag(
                          text: plural(
                            item.src.extraFields,
                            'champ supplémentaire ignoré',
                            'champs supplémentaires ignorés',
                          ),
                          color: cs.outline,
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _side('Recto', _front),
                  const SizedBox(height: 14),
                  _side('Verso', _back),
                  const SizedBox(height: 6),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: () {
                        final f = _front.text;
                        _front.text = _back.text;
                        _back.text = f;
                      },
                      icon: const Icon(Icons.swap_vert, size: 18),
                      label: const Text('Inverser recto et verso'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const Divider(),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
            child: Row(
              children: [
                IconButton(
                  tooltip: 'Carte précédente',
                  icon: const Icon(Icons.arrow_back),
                  onPressed: _pos == 0 ? null : _previous,
                ),
                const Spacer(),
                OutlinedButton(
                  onPressed: () => _decide(_Status.skipped),
                  child: const Text('Ignorer'),
                ),
                const SizedBox(width: 10),
                FilledButton(
                  onPressed: valid ? () => _decide(_Status.kept) : null,
                  child: const Text('Valider'),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _side(String label, TextEditingController controller) {
    final length = textLength(controller.text);
    final over = length > _limit;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: controller,
          minLines: 3,
          maxLines: 12,
          decoration: InputDecoration(
            labelText: label,
            alignLabelWithHint: true,
            border: const OutlineInputBorder(),
            counterText: '$length / $_limit',
            errorText: over
                ? '${length - _limit} caractères en trop'
                : null,
          ),
        ),
        if (over)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () =>
                  controller.text = shorten(controller.text, _limit),
              icon: const Icon(Icons.content_cut, size: 18),
              label: Text('Raccourcir à $_limit caractères'),
            ),
          ),
      ],
    );
  }

  Widget _buildDone(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final result = _result();
    final dropped = _items.length - result.length;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 40),
      child: ReadableWidth(
        maxWidth: 520,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              result.isEmpty
                  ? 'Aucune carte à ajouter'
                  : '${plural(result.length, 'carte prête', 'cartes prêtes')}',
              style: theme.textTheme.headlineSmall,
            ),
            const SizedBox(height: 6),
            Text(
              dropped == 0
                  ? 'Toutes les cartes du fichier sont conservées.'
                  : '${plural(dropped, 'carte ignorée', 'cartes ignorées')}.',
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: cs.onSurfaceVariant),
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: () => Navigator.pop(context, result),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Text(
                  result.isEmpty ? 'Fermer' : 'Ajouter au paquet',
                ),
              ),
            ),
            if (_queue.isNotEmpty) ...[
              const SizedBox(height: 8),
              TextButton(
                onPressed: () {
                  setState(() {
                    _pos = _queue.length - 1;
                    _phase = _Phase.review;
                  });
                  _load();
                },
                child: const Text('Revenir à la revue'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _StatRow extends StatelessWidget {
  const _StatRow({
    required this.icon,
    required this.color,
    required this.label,
    required this.detail,
  });

  final IconData icon;
  final Color color;
  final String label;
  final String detail;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        border: Border.all(color: theme.colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(icon, color: color),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: theme.textTheme.titleSmall),
                Text(
                  detail,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag({required this.text, required this.color});
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        border: Border.all(color: color),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(color: color),
      ),
    );
  }
}
