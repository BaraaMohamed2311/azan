import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

import 'core/theme.dart';
import 'data/municipalities.dart';
import 'data/quran.dart';
import 'screens/root_shell.dart';
import 'state/app_settings.dart';

/// أذان ليبيا — Flutter port of the original Expo/React Native app.
///
/// Everything runs locally: prayer times (adhan), Umm al-Qura Hijri calendar,
/// the full Qalun mushaf, athkar, qibla, and 104 Libyan municipalities.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Future.wait([
    MunicipalityData.load(),
    QuranData.load(),
  ]);
  final settings = AppSettings();
  await settings.load();
  runApp(
    ChangeNotifierProvider.value(
      value: settings,
      child: const AthanLibyaApp(),
    ),
  );
}

class AthanLibyaApp extends StatelessWidget {
  const AthanLibyaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'أذان ليبيا',
      debugShowCheckedModeBanner: false,
      locale: const Locale('ar'),
      supportedLocales: const [Locale('ar')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: buildAppTheme(Brightness.light),
      darkTheme: buildAppTheme(Brightness.dark),
      themeMode: ThemeMode.system,
      home: const RootShell(),
    );
  }
}
