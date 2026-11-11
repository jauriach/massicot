import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';

import '../anki/importer.dart';
import '../models.dart';
import '../store.dart';
import 'card_editor.dart';
import 'common.dart';
import 'deck_form.dart';
import 'preview_page.dart';
import 'review_page.dart';

/// Contenu d'un paquet : cartes, import Anki, réglages, export PDF.
class DeckView extends StatelessWidget {
  const DeckView({
    super.key,
    required this.store,
    required this.deck,
    required this.embedded,
    required this.onDeleted,
  });

  final DeckStore store;
  final Deck deck;

  /// Vrai quand la vue est affichée à côté de la liste (grand écran).
  final bool embedded;
  final VoidCallback onDeleted;

  Future<void> _editCard(BuildContext context, Flashcard? card) async {
    var current = card;
    while (true) {
      final result = await Navigator.push<CardEdit>(
        context,
        MaterialPageRoute(
          fullscreenDialog: true,
          builder: (_) => CardEditorPage(deck: deck, card: current),
        ),
      );
      if (result == null) return;
      if (result.delete) {
        if (current != null) deck.cards.remove(current);
        store.changed();
        return;
      }
      if (current == null) {
        deck.cards.add(
          Flashcard(id: newId(), front: result.front, back: result.back),
        );
      } else {
        current
          ..front = result.front
          ..back = result.back;
      }
      store.changed();
      if (!result.addAnother || !context.mounted) return;
      current = null;
    }
  }

  Future<void> _settings(BuildContext context) async {
    final result = await Navigator.push<Deck>(
      context,
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => DeckFormPage(existing: deck),
      ),
    );
    if (result != null) store.changed();
  }

  Future<void> _delete(BuildContext context) async {
    final ok = await confirm(
      context,
      title: 'Supprimer ce paquet ?',
      message:
          '« ${deck.name} » et ses ${plural(deck.cards.length, 'carte', 'cartes')} '
          'seront supprimés définitivement.',
      action: 'Supprimer',
    );
    if (!ok) return;
    store.removeDeck(deck);
    onDeleted();
  }

  Future<void> _import(BuildContext context) async {
    final XFile? file = await openFile();
    if (file == null) return;
    List<ImportedCard> imported;
    try {
      imported = importAnkiFile(await file.readAsBytes());
    } on AnkiImportException catch (e) {
      if (context.mounted) {
        await showMessage(context, 'Import impossible', e.message);
      }
      return;
    } catch (e) {
      if (context.mounted) {
        await showMessage(
          context,
          'Import impossible',
          'Ce fichier n\'a pas pu être lu comme un export Anki '
              '(.apkg, .colpkg ou .txt).',
        );
      }
      return;
    }
    if (!context.mounted) return;
    if (imported.isEmpty) {
      await showMessage(
        context,
        'Aucune carte',
        'Aucune note exploitable n\'a été trouvée dans ce fichier.',
      );
      return;
    }
    final kept = await Navigator.push<List<Flashcard>>(
      context,
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => ReviewPage(
          deck: deck,
          imported: imported,
          sourceName: file.name,
        ),
      ),
    );
    if (kept == null || kept.isEmpty) return;
    deck.cards.addAll(kept);
    store.changed();
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${plural(kept.length, 'carte ajoutée', 'cartes ajoutées')} au paquet.',
          ),
        ),
      );
    }
  }

  void _preview(BuildContext context) {
    Navigator.push<void>(
      context,
      MaterialPageRoute(builder: (_) => PreviewPage(deck: deck)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final theme = Theme.of(context);
        final cs = theme.colorScheme;
        final layout = deck.layout;
        final limit = layout.charLimit;
        final count = deck.cards.length;
        final over = deck.cards.where((c) => isOverLimit(c, limit)).length;

        return Scaffold(
          appBar: AppBar(
            automaticallyImplyLeading: !embedded,
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(deck.name, maxLines: 1, overflow: TextOverflow.ellipsis),
                Text(
                  '${layout.perPage} par feuille · $limit caractères max',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: cs.onSurfaceVariant),
                ),
              ],
            ),
            actions: [
              IconButton(
                tooltip: 'Importer depuis Anki',
                icon: const Icon(Icons.file_download_outlined),
                onPressed: () => _import(context),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: FilledButton.icon(
                  onPressed: count == 0 ? null : () => _preview(context),
                  icon: const Icon(Icons.print_outlined, size: 18),
                  label: const Text('PDF'),
                ),
              ),
              PopupMenuButton<String>(
                tooltip: 'Autres actions',
                onSelected: (value) {
                  if (value == 'settings') _settings(context);
                  if (value == 'delete') _delete(context);
                },
                itemBuilder: (context) => const [
                  PopupMenuItem<String>(
                    value: 'settings',
                    child: Text('Réglages du paquet'),
                  ),
                  PopupMenuItem<String>(
                    value: 'delete',
                    child: Text('Supprimer le paquet'),
                  ),
                ],
              ),
              const SizedBox(width: 4),
            ],
          ),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () => _editCard(context, null),
            icon: const Icon(Icons.add),
            label: const Text('Carte'),
          ),
          body: count == 0
              ? EmptyState(
                  icon: Icons.note_add_outlined,
                  title: 'Paquet vide',
                  message:
                      'Ajoutez vos cartes une à une, ou importez un export '
                      'AnkiMobile (.apkg ou .txt). Chaque face est limitée à '
                      '$limit caractères.',
                  actions: [
                    FilledButton.icon(
                      onPressed: () => _editCard(context, null),
                      icon: const Icon(Icons.add),
                      label: const Text('Ajouter une carte'),
                    ),
                    OutlinedButton.icon(
                      onPressed: () => _import(context),
                      icon: const Icon(Icons.file_download_outlined),
                      label: const Text('Importer depuis Anki'),
                    ),
                  ],
                )
              : Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              '${plural(count, 'carte', 'cartes')} · '
                              '${plural(layout.sheetCount(count), 'feuille A4', 'feuilles A4')}',
                              style: theme.textTheme.bodyMedium
                                  ?.copyWith(color: cs.onSurfaceVariant),
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (over > 0)
                      Container(
                        width: double.infinity,
                        margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: cs.errorContainer,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '${plural(over, 'carte dépasse', 'cartes dépassent')} '
                          'la limite de $limit caractères. Leur texte sera '
                          'réduit à l\'impression ; raccourcissez-les pour '
                          'garder une taille uniforme.',
                          style: theme.textTheme.bodySmall
                              ?.copyWith(color: cs.onErrorContainer),
                        ),
                      ),
                    const Divider(),
                    Expanded(
                      child: ListView.separated(
                        padding: const EdgeInsets.only(bottom: 96),
                        itemCount: count,
                        separatorBuilder: (_, __) =>
                            const Divider(indent: 56),
                        itemBuilder: (context, i) {
                          final card = deck.cards[i];
                          final tooLong = isOverLimit(card, limit);
                          return ListTile(
                            leading: SizedBox(
                              width: 28,
                              child: Text(
                                '${i + 1}',
                                textAlign: TextAlign.right,
                                style: theme.textTheme.bodySmall
                                    ?.copyWith(color: cs.outline),
                              ),
                            ),
                            title: Text(
                              card.front.replaceAll('\n', ' '),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            subtitle: Text(
                              card.back.replaceAll('\n', ' '),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            trailing: tooLong
                                ? Tooltip(
                                    message: 'Texte trop long',
                                    child: Icon(
                                      Icons.error_outline,
                                      color: cs.error,
                                      size: 20,
                                    ),
                                  )
                                : null,
                            onTap: () => _editCard(context, card),
                          );
                        },
                      ),
                    ),
                  ],
                ),
        );
      },
    );
  }
}
