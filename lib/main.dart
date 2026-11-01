import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app.dart';
import 'data/photo_store.dart';
import 'data/repository.dart';
import 'services/notifications.dart';
import 'services/sheets_sync.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      systemNavigationBarColor: Colors.white,
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
  );

  await PhotoStore.init();
  // Everything below works offline; nothing here touches the network.
  final repo = await AppRepo.create();
  final sync = SheetsSync(repo)..attach();

  // Reminders are optional, so a failure here must not stop the app.
  await Reminders.init();
  if (repo.reminderEnabled) {
    await Reminders.scheduleDaily(
      hour: repo.reminderHour,
      minute: repo.reminderMinute,
      lowCount: repo.totals.lowCount,
      outCount: repo.totals.outCount,
      s: repo.s,
    );
  }

  runApp(StockSaathiApp(repo: repo, sync: sync));
}
