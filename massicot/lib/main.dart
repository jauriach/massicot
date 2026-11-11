import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'store.dart';
import 'ui/common.dart';
import 'ui/home_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final store = DeckStore();
  await store.load();
  runApp(MassicotApp(store: store));
}

class MassicotApp extends StatelessWidget {
  const MassicotApp({super.key, required this.store});
  final DeckStore store;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Massicot',
      debugShowCheckedModeBanner: false,
      locale: const Locale('fr'),
      supportedLocales: const [Locale('fr')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      theme: buildTheme(Brightness.light),
      darkTheme: buildTheme(Brightness.dark),
      home: HomePage(store: store),
    );
  }
}
