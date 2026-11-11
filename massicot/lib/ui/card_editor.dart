import 'package:flutter/material.dart';

import '../models.dart';
import 'common.dart';

class CardEdit {
  const CardEdit({
    this.front = '',
    this.back = '',
    this.delete = false,
    this.addAnother = false,
  });

  final String front;
  final String back;
  final bool delete;
  final bool addAnother;
}

/// Saisie d'une carte. La limite du paquet est appliquée à chaque face.
class CardEditorPage extends StatefulWidget {
  const CardEditorPage({super.key, required this.deck, this.card});
  final Deck deck;
  final Flashcard? card;

  @override
  State<CardEditorPage> createState() => _CardEditorPageState();
}

class _CardEditorPageState extends State<CardEditorPage> {
  late final TextEditingController _front;
  late final TextEditingController _back;

  @override
  void initState() {
    super.initState();
    _front = TextEditingController(text: widget.card?.front ?? '');
    _back = TextEditingController(text: widget.card?.back ?? '');
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

  int get _limit => widget.deck.charLimit;

  bool get _valid =>
      _front.text.trim().isNotEmpty &&
      _back.text.trim().isNotEmpty &&
      textLength(_front.text) <= _limit &&
      textLength(_back.text) <= _limit;

  void _save({bool addAnother = false}) {
    Navigator.pop(
      context,
      CardEdit(
        front: _front.text.trim(),
        back: _back.text.trim(),
        addAnother: addAnother,
      ),
    );
  }

  Future<void> _delete() async {
    final ok = await confirm(
      context,
      title: 'Supprimer cette carte ?',
      message: 'Cette action est définitive.',
      action: 'Supprimer',
    );
    if (ok && mounted) Navigator.pop(context, const CardEdit(delete: true));
  }

  @override
  Widget build(BuildContext context) {
    final isNew = widget.card == null;
    return Scaffold(
      appBar: AppBar(
        title: Text(isNew ? 'Nouvelle carte' : 'Modifier la carte'),
        actions: [
          if (!isNew)
            IconButton(
              tooltip: 'Supprimer la carte',
              icon: const Icon(Icons.delete_outline),
              onPressed: _delete,
            ),
          Padding(
            padding: const EdgeInsets.only(left: 4, right: 12),
            child: FilledButton(
              onPressed: _valid ? _save : null,
              child: const Text('Enregistrer'),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
        child: ReadableWidth(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: _front,
                autofocus: isNew,
                minLines: 3,
                maxLines: null,
                maxLength: _limit,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Recto',
                  alignLabelWithHint: true,
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _back,
                minLines: 3,
                maxLines: null,
                maxLength: _limit,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Verso',
                  alignLabelWithHint: true,
                  border: OutlineInputBorder(),
                ),
              ),
              if (isNew) ...[
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerRight,
                  child: OutlinedButton.icon(
                    onPressed: _valid ? () => _save(addAnother: true) : null,
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Enregistrer et ajouter une autre'),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
