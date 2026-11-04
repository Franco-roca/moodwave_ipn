import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import '../features/analytics/presentation/screens/patterns_screen.dart';
import '../features/reports/presentation/report_screen.dart';

import 'state.dart';
import '../features/security/presentation/security_screen.dart';
import '../features/records/presentation/editor.dart';
import 'screens.dart';

class MoodWaveApp extends ConsumerStatefulWidget {
  const MoodWaveApp({super.key});
  @override
  ConsumerState<MoodWaveApp> createState() => _MoodWaveAppState();
}

class _MoodWaveAppState extends ConsumerState<MoodWaveApp>
    with WidgetsBindingObserver {
  late final AppStore store;
  late final GoRouter router;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    store = ref.read(storeProvider);
    router = GoRouter(
      initialLocation: '/lock',
      refreshListenable: store,
      redirect: (context, state) {
        if (!store.unlocked) return state.uri.path == '/lock' ? null : '/lock';
        if (state.uri.path == '/lock') return '/today';
        return null;
      },
      routes: [
        GoRoute(
          path: '/lock',
          builder: (c, s) => ListenableBuilder(
            listenable: store,
            builder: (context, _) =>
                SecurityScreen(key: ValueKey(store.lockVersion)),
          ),
        ),
        StatefulShellRoute.indexedStack(
          builder: (c, s, shell) => Scaffold(
            body: shell,
            bottomNavigationBar: Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(28),
                child: NavigationBar(
                  height: 72,
                  selectedIndex: shell.currentIndex,
                  onDestinationSelected: (i) => shell.goBranch(i),
                  destinations: const [
                    NavigationDestination(
                      icon: Icon(Icons.water_drop_outlined),
                      selectedIcon: Icon(Icons.water_drop),
                      label: 'Hoy',
                    ),
                    NavigationDestination(
                      icon: Icon(Icons.calendar_month),
                      label: 'Calendario',
                    ),
                    NavigationDestination(
                      icon: Icon(Icons.insights),
                      label: 'Análisis',
                    ),
                    NavigationDestination(
                      icon: Icon(Icons.person_outline),
                      label: 'Perfil',
                    ),
                  ],
                ),
              ),
            ),
          ),
          branches: [
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/today',
                  builder: (c, s) =>
                      Editor(key: ValueKey('today-${dateStamp()}')),
                ),
              ],
            ),
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/calendar',
                  builder: (c, s) => const CalendarScreen(),
                ),
              ],
            ),
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/statistics',
                  builder: (c, s) => const PatternsScreen(),
                ),
              ],
            ),
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/profile',
                  builder: (c, s) => const ProfileScreen(),
                ),
              ],
            ),
          ],
        ),
        GoRoute(path: '/settings', builder: (c, s) => const SettingsScreen()),
        GoRoute(path: '/reports', builder: (c, s) => const ReportScreen()),
        GoRoute(
          path: '/pin',
          builder: (c, s) => const SecurityScreen(changePin: true),
        ),
        GoRoute(
          path: '/edit/:date',
          builder: (c, s) =>
              Editor(date: DateTime.parse(s.pathParameters['date']!)),
        ),
      ],
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused && !store.authenticating) {
      store.lock();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    router.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: store,
    builder: (context, _) => MaterialApp.router(
      title: 'MoodWave',
      locale: const Locale('es', 'MX'),
      supportedLocales: const [Locale('es', 'MX')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      debugShowCheckedModeBanner: false,
      theme: waveTheme(Brightness.light),
      darkTheme: waveTheme(Brightness.dark),
      themeMode: store.theme,
      routerConfig: router,
    ),
  );
}

String dateStamp() => DateTime.now().toString().substring(0, 10);
ThemeData waveTheme(Brightness brightness) {
  final dark = brightness == Brightness.dark;
  final scheme = ColorScheme.fromSeed(
    seedColor: const Color(0xff007f7b),
    brightness: brightness,
  );
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: dark
        ? const Color(0xff0d2025)
        : const Color(0xffeef9fb),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: dark ? const Color(0xff173238) : Colors.white,
      indicatorColor: scheme.primaryContainer,
      labelTextStyle: const WidgetStatePropertyAll(
        TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
      ),
    ),
    chipTheme: ChipThemeData(
      side: BorderSide(color: scheme.outlineVariant.withValues(alpha: .5)),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      selectedColor: scheme.primaryContainer,
    ),
    cardTheme: CardThemeData(
      elevation: dark ? 0 : 1,
      shadowColor: scheme.primary.withValues(alpha: .10),
      color: dark ? const Color(0xff173238) : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide.none,
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(48, 56),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
    ),
  );
}
