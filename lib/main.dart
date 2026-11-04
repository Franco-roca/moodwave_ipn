import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'app/app.dart';
import 'app/state.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('es_MX');
  final store = AppStore();
  await store.initialize();
  runApp(
    ProviderScope(
      overrides: [storeProvider.overrideWithValue(store)],
      child: const MoodWaveApp(),
    ),
  );
}
