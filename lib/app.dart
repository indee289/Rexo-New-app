import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

import 'core/theme.dart';
import 'data/repository.dart';
import 'services/sheets_sync.dart';
import 'ui/shell.dart';

class StockSaathiApp extends StatefulWidget {
  const StockSaathiApp({super.key, required this.repo, required this.sync});

  final AppRepo repo;
  final SheetsSync sync;

  @override
  State<StockSaathiApp> createState() => _StockSaathiAppState();
}

class _StockSaathiAppState extends State<StockSaathiApp>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // A pending push goes out as soon as the app is on screen again.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.sync.restoreSession();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      widget.sync.onResume();
    } else if (state == AppLifecycleState.paused) {
      // Leaving the app is a good moment to flush whatever is pending.
      widget.sync.pushNow();
    }
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<AppRepo>.value(value: widget.repo),
        Provider<SheetsSync>.value(value: widget.sync),
      ],
      child: Consumer<AppRepo>(
        builder: (context, repo, _) => MaterialApp(
          title: 'StockSaathi',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.build(),
          // Light only, by design.
          themeMode: ThemeMode.light,
          locale: Locale(repo.languageCode),
          supportedLocales: const [Locale('hi'), Locale('en')],
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: const Shell(),
        ),
      ),
    );
  }
}
