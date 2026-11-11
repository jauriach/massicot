# Massicot

Flashcards recto verso à imprimer sur A4 et à couper au massicot.
Application Flutter pour Android, macOS et Windows, entièrement hors ligne.

## Ce que fait l'application

- **Paquets** : chaque paquet fixe à l'avance son format (2 à 20 cartes par
  feuille) et la taille du texte. Les deux déterminent la **limite de
  caractères par face**, affichée en face de chaque format.
- **Mot-clé** facultatif, imprimé en haut à gauche du recto et du verso.
- **PDF A4** : une page recto puis une page verso par feuille. Le verso est
  disposé en miroir pour que chaque carte retrouve son dos. Grille sans
  gouttière, bords droits, traits de coupe fins au recto seulement.
- **Import AnkiMobile** : paquets `.apkg` / `.colpkg` et export texte `.txt`.
  HTML, sons, images, LaTeX et textes à trous sont nettoyés par regex, puis
  les cartes trop longues, incomplètes ou privées d'une image passent en
  **revue carte par carte**.

## Imprimer

1. Recto verso, retournement sur le **bord long** (ou bord court si le paquet
   est réglé ainsi).
2. Échelle **100 %** / « taille réelle ». Jamais « ajuster à la page ».
3. Faire un essai sur une feuille avant de lancer tout le paquet : chaque
   imprimante décale légèrement le verso (souvent 1 à 2 mm).

## Compiler

Les dossiers `android/`, `macos/` et `windows/` ne sont pas versionnés : ils
sont générés par Flutter.

### Avec GitHub Actions (sans rien installer)

Pousser ce dossier sur un dépôt GitHub, branche `main`. Le workflow
`.github/workflows/build.yml` lance les tests et produit trois artefacts :
`Massicot-android` (APK), `Massicot-macos` (zip de l'app) et
`Massicot-windows` (dossier avec `massicot.exe`).

- macOS : l'app n'est pas signée par un compte développeur. Au premier
  lancement : clic droit › Ouvrir, ou `xattr -cr massicot.app`.
- Android : l'APK est signé avec la clé de débogage (installation manuelle).

### En local

```
flutter create --platforms=android,macos,windows --org fr.massicot --project-name massicot .
rm -f test/widget_test.dart
flutter pub get
flutter test
flutter run            # ou : flutter build apk | macos | windows
```

Sur macOS, ajouter aux deux fichiers `macos/Runner/*.entitlements` :
`com.apple.security.files.user-selected.read-write` et
`com.apple.security.print` (booléens à `true`), sinon l'import de fichier et
l'impression sont bloqués par le bac à sable.

## Limites connues

- Les paquets `.apkg` au nouveau format compressé (`collection.anki21b`) ne
  sont pas lus : dans AnkiMobile, activer « Prendre en charge les anciennes
  versions d'Anki » à l'export, ou exporter en texte.
- Les images et les sons ne sont pas repris.
- Police du PDF : DejaVu Sans (latin, grec, cyrillique). Pas de CJK.

## Organisation du code

| Fichier | Rôle |
| --- | --- |
| `lib/layout.dart` | Géométrie A4, limite de caractères, miroir recto verso |
| `lib/pdf_export.dart` | Génération du PDF |
| `lib/anki/clean.dart` | Nettoyage regex des champs Anki |
| `lib/anki/sqlite_reader.dart` | Lecteur SQLite en Dart pur |
| `lib/anki/importer.dart` | Lecture `.apkg` et `.txt` |
| `lib/ui/` | Écrans |
| `test/` | Tests de la géométrie et de l'import |
