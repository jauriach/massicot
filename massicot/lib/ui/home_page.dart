import 'package:flutter/material.dart';

import '../models.dart';
import '../store.dart';
import 'common.dart';
import 'deck_form.dart';
import 'deck_view.dart';

/// Liste des paquets. Sur grand écran (Mac, Windows, tablette), la liste
/// reste à gauche et le paquet s'ouvre à droite ; sur téléphone, le paquet
/// s'ouvre dans une nouvelle page.
class HomePage extends StatefulWidget {
  const HomePage({super.key, required this.store});
  final DeckStore store;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  String? _selectedId;

  DeckStore get store => widget.store;

  Future<void> _newDeck(bool wide) async {
    final deck = await Navigator.push<Deck>(
      context,
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => const DeckFormPage(),
      ),
    );
    if (deck == null || !mounted) return;
    store.addDeck(deck);
    _open(deck, wide);
  }

  void _open(Deck deck, bool wide) {
    setState(() => _selectedId = deck.id);
    if (wide) return;
    Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (routeContext) => DeckView(
          store: store,
          deck: deck,
          embedded: false,
          onDeleted: () => Navigator.pop(routeContext),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        return LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth >= 860;
            final list = _DeckList(
              store: store,
              selectedId: wide ? _selectedId : null,
              showFab: !wide,
              onNew: () => _newDeck(wide),
              onOpen: (d) => _open(d, wide),
            );
            if (!wide) return list;

            final selected =
                _selectedId == null ? null : store.byId(_selectedId!);
            return Scaffold(
              body: Row(
                children: [
                  SizedBox(width: 320, child: list),
                  const VerticalDivider(width: 1),
                  Expanded(
                    child: selected == null
                        ? const Scaffold(
                            body: EmptyState(
                              icon: Icons.style_outlined,
                              title: 'Aucun paquet sélectionné',
                              message:
                                  'Choisissez un paquet dans la liste, ou '
                                  'créez-en un nouveau.',
                            ),
                          )
                        : DeckView(
                            key: ValueKey(selected.id),
                            store: store,
                            deck: selected,
                            embedded: true,
                            onDeleted: () =>
                                setState(() => _selectedId = null),
                          ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class _DeckList extends StatelessWidget {
  const _DeckList({
    required this.store,
    required this.selectedId,
    required this.showFab,
    required this.onNew,
    required this.onOpen,
  });

  final DeckStore store;
  final String? selectedId;
  final bool showFab;
  final VoidCallback onNew;
  final ValueChanged<Deck> onOpen;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Paquets'),
        actions: [
          if (!showFab)
            IconButton(
              tooltip: 'Nouveau paquet',
              icon: const Icon(Icons.add),
              onPressed: onNew,
            ),
          const SizedBox(width: 8),
        ],
      ),
      floatingActionButton: showFab
          ? FloatingActionButton.extended(
              onPressed: onNew,
              icon: const Icon(Icons.add),
              label: const Text('Nouveau paquet'),
            )
          : null,
      body: store.decks.isEmpty
          ? EmptyState(
              icon: Icons.style_outlined,
              title: 'Aucun paquet',
              message:
                  'Créez un paquet : vous choisirez le nombre de cartes par '
                  'feuille A4, ce qui fixe la longueur de texte autorisée.',
              actions: [
                FilledButton.icon(
                  onPressed: onNew,
                  icon: const Icon(Icons.add),
                  label: const Text('Nouveau paquet'),
                ),
              ],
            )
          : ListView.builder(
              padding: const EdgeInsets.fromLTRB(8, 4, 8, 96),
              itemCount: store.decks.length,
              itemBuilder: (context, i) {
                final d = store.decks[i];
                final selected = d.id == selectedId;
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: ListTile(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    selected: selected,
                    selectedTileColor: theme.colorScheme.secondaryContainer,
                    selectedColor: theme.colorScheme.onSecondaryContainer,
                    title: Text(
                      d.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text(
                      '${plural(d.cards.length, 'carte', 'cartes')} · '
                      '${d.layout.perPage} par feuille',
                    ),
                    trailing: const Icon(Icons.chevron_right, size: 20),
                    onTap: () => onOpen(d),
                  ),
                );
              },
            ),
    );
  }
}
