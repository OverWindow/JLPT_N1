import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'screens/home_screen.dart';
import 'services/progress_store.dart';

void main() => runApp(const WordApp());

class WordApp extends StatelessWidget {
  const WordApp({super.key, this.progressStore});
  final ProgressStore? progressStore;

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: '일본어 단어장',
    debugShowCheckedModeBanner: false,
    locale: const Locale('ko'),
    supportedLocales: const [Locale('ko')],
    localizationsDelegates: GlobalMaterialLocalizations.delegates,
    theme: ThemeData(
      colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF455C48)),
      scaffoldBackgroundColor: const Color(0xFFFAFAF7),
      appBarTheme: const AppBarTheme(centerTitle: false),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(56),
          textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(52)),
      ),
    ),
    home: HomeScreen(progressStore: progressStore),
  );
}
