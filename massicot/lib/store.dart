import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import 'models.dart';

/// Paquets enregistrés dans un fichier JSON local (aucun compte, aucun réseau).
class DeckStore extends ChangeNotifier {
  final List<Deck> decks = <Deck>[];
  File? _file;
  Future<void> _pending = Future<void>.value();

  Future<void> load() async {
    try {
      final dir = await getApplicationSupportDirectory();
      final file = File('${dir.path}${Platform.pathSeparator}decks.json');
      _file = file;
      if (await file.exists()) {
        try {
          final data =
              jsonDecode(await file.readAsString()) as Map<String, dynamic>;
          final list = (data['decks'] as List?) ?? const [];
          decks
            ..clear()
            ..addAll(
                list.map((e) => Deck.fromJson(e as Map<String, dynamic>)));
        } catch (_) {
          // Fichier illisible : on le met de côté plutôt que de l'écraser.
          await file.copy('${file.path}.illisible');
        }
      }
    } catch (_) {
      // Pas de stockage disponible : l'appli reste utilisable en mémoire.
    }
  }

  Deck? byId(String id) {
    for (final d in decks) {
      if (d.id == id) return d;
    }
    return null;
  }

  void addDeck(Deck deck) {
    decks.add(deck);
    changed();
  }

  void removeDeck(Deck deck) {
    decks.remove(deck);
    changed();
  }

  /// À appeler après toute modification d'un paquet ou de ses cartes.
  void changed() {
    notifyListeners();
    final file = _file;
    if (file == null) return;
    final json = jsonEncode({
      'version': 1,
      'decks': decks.map((d) => d.toJson()).toList(),
    });
    _pending = _pending.then((_) async {
      try {
        final tmp = File('${file.path}.tmp');
        await tmp.writeAsString(json, flush: true);
        await tmp.rename(file.path);
      } catch (_) {
        try {
          await file.writeAsString(json, flush: true);
        } catch (_) {}
      }
    });
  }
}
