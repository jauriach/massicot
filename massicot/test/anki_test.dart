import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:massicot/anki/clean.dart';
import 'package:massicot/anki/importer.dart';

void main() {
  group('nettoyage', () {
    test('balises et entités', () {
      expect(cleanAnkiField('<div><b>Paris</b></div>').text, 'Paris');
      expect(
        cleanAnkiField(
                '<div>Ligne 1</div><div>Ligne 2&nbsp;: &eacute;t&eacute; &amp; hiver</div>')
            .text,
        'Ligne 1\nLigne 2 : été & hiver',
      );
      expect(cleanAnkiField('a &lt; b et 2 &gt; 1').text, 'a < b et 2 > 1');
      expect(cleanAnkiField('si a < b alors').text, 'si a < b alors');
    });

    test('sons et images', () {
      final c = cleanAnkiField('R&#233;ponse<br>sur deux lignes[sound:r.mp3]');
      expect(c.text, 'Réponse\nsur deux lignes');
      expect(c.hadMedia, isTrue);
      final img = cleanAnkiField('Schéma <img src="coeur.png">');
      expect(img.text, 'Schéma');
      expect(img.hadMedia, isTrue);
      expect(cleanAnkiField('Texte simple').hadMedia, isFalse);
    });

    test('styles, listes, tableaux, LaTeX', () {
      expect(
        cleanAnkiField(
                '<style>.card{color:red}</style><ul><li>un</li><li>deux</li></ul>')
            .text,
        '• un\n• deux',
      );
      expect(
        cleanAnkiField('<table><tr><td>A</td><td>B</td></tr></table>').text,
        'A B',
      );
      expect(cleanAnkiField(r'[latex]x^2[/latex] et \(y\)').text, 'x^2 et y');
    });

    test('textes à trous', () {
      const raw = "La {{c1::mitochondrie::organite}} produit l'{{c2::ATP}}.";
      expect(hasCloze(raw), isTrue);
      expect(clozeFront(raw), "La [organite] produit l'[…].");
      expect(clozeBack(raw), "La mitochondrie produit l'ATP.");
    });
  });

  group('export texte', () {
    test('en-têtes AnkiMobile et colonnes techniques', () {
      const text = '#separator:tab\n#html:true\n#guid column:1\n'
          '#notetype column:2\n#deck column:3\n#tags column:6\n'
          'abc\tBasique\tHistoire\t<b>1789</b>\tRévolution\tdate\n'
          'def\tBasique\tHistoire\t"Deux\nlignes"\t"Il a dit ""oui"""\t\n';
      final cards = importAnkiText(text);
      expect(cards.length, 2);
      expect(cards[0].front, '1789');
      expect(cards[0].back, 'Révolution');
      expect(cards[1].front, 'Deux\nlignes');
      expect(cards[1].back, 'Il a dit "oui"');
    });

    test('sans en-tête, séparateur deviné', () {
      final cards = importAnkiText('chat;cat\nchien;dog\n');
      expect(cards.length, 2);
      expect(cards[1].back, 'dog');
    });
  });

  group('paquet .apkg', () {
    test('lecture de la collection (débordement et pages internes)', () {
      final bytes = File('test/fixtures/sample.apkg').readAsBytesSync();
      final cards = importAnkiFile(Uint8List.fromList(bytes));
      expect(cards.length, 300);
      expect(cards[0].front, 'Capitale de la France ?');
      expect(cards[0].back, 'Paris');
      expect(cards[1].hadMedia, isTrue);
      expect(cards[2].wasCloze, isTrue);
      expect(cards[2].front, "La [organite] produit l'[…].");
      expect(cards[2].back, "La mitochondrie produit l'ATP.\nNote complémentaire");
      expect(cards[3].extraFields, 1);
      expect(cards[4].back.length, 2300 * 4 - 1);
      expect(cards[299].front, 'Question 294');
    });

    test('nouveau format compressé : message explicite', () {
      final bytes = File('test/fixtures/newformat.apkg').readAsBytesSync();
      expect(
        () => importAnkiFile(Uint8List.fromList(bytes)),
        throwsA(isA<AnkiImportException>()),
      );
    });
  });
}
