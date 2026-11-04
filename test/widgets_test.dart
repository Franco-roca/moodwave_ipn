import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:moodwave/app/app.dart';
import 'package:moodwave/app/screens.dart';
import 'package:moodwave/app/state.dart';
import 'package:moodwave/core/widgets.dart';
import 'package:moodwave/features/records/domain/record.dart';
import 'package:moodwave/features/records/presentation/editor.dart';
import 'package:moodwave/features/security/data/security.dart';

class FakeBiometric implements BiometricService {
  @override
  Future<BioStatus> availability() async => BioStatus.available;
  @override
  Future<BioStatus> authenticate() async => BioStatus.success;
  @override
  Future<void> cancel() async {}
}

void main() {
  setUpAll(() async {
    await initializeDateFormatting('es_MX');
  });
  testWidgets('Selector muestra ocho emociones y selecciona por nombre', (
    tester,
  ) async {
    Mood? chosen;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MoodSelector(value: null, onChanged: (v) => chosen = v),
        ),
      ),
    );
    expect(find.text('Excelente'), findsOneWidget);
    await tester.tap(find.text('Feliz'));
    expect(chosen, Mood.happy);
  });
  testWidgets('Reflexión limita a 300 caracteres', (tester) async {
    final controller = TextEditingController();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: ReflectionField(controller: controller)),
      ),
    );
    await tester.enterText(
      find.byType(TextField),
      List.filled(301, 'a').join(),
    );
    expect(controller.text.length, 300);
    await tester.pumpWidget(const SizedBox());
    controller.dispose();
  });
  testWidgets('Estado vacío ofrece crear registro', (tester) async {
    var tapped = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: EmptyState(onCreate: () => tapped = true)),
      ),
    );
    await tester.tap(find.text('Crear mi primer registro'));
    expect(tapped, isTrue);
  });
  testWidgets('Cambiar periodo semanal y mensual', (tester) async {
    final store = AppStore();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [storeProvider.overrideWithValue(store)],
        child: MaterialApp(home: Scaffold(body: const StatisticsScreen())),
      ),
    );
    await tester.tap(find.text('Mensual'));
    await tester.pumpAndSettle();
    final segmented = tester.widget<SegmentedButton<bool>>(
      find.byType(SegmentedButton<bool>),
    );
    expect(segmented.selected, {true});
    expect(tester.takeException(), isNull);
  });
  testWidgets('Eliminar exige confirmar y permite cancelar', (tester) async {
    bool? result;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async => result = await confirmDelete(context),
              child: const Text('Abrir'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Abrir'));
    await tester.pumpAndSettle();
    expect(find.text('¿Eliminar este registro?'), findsOneWidget);
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();
    expect(result, isFalse);
  });
  testWidgets('Arranque cerrado y ciclo de vida vuelve a bloquear', (
    tester,
  ) async {
    final store = AppStore()..biometrics = FakeBiometric();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [storeProvider.overrideWithValue(store)],
        child: const MoodWaveApp(),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Crea tu PIN'), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);
    store.unlock();
    await tester.pumpAndSettle();
    expect(find.byType(NavigationBar), findsOneWidget);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    expect(store.unlocked, isFalse);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(find.byType(NavigationBar), findsNothing);
    expect(find.text('Crea tu PIN'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('Pantalla pequeña permite editor sin overflow', (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final store = AppStore();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [storeProvider.overrideWithValue(store)],
        child: MaterialApp(home: const Editor()),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
  testWidgets('PIN se confirma antes de almacenar y desbloquear', (
    tester,
  ) async {
    final values = <String, String>{};
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
          (call) async {
            final a = Map<String, dynamic>.from(call.arguments as Map);
            if (call.method == 'write') values[a['key']] = a['value'];
            if (call.method == 'read') return values[a['key']];
            return null;
          },
        );
    final store = AppStore()..biometrics = FakeBiometric();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [storeProvider.overrideWithValue(store)],
        child: const MoodWaveApp(),
      ),
    );
    await tester.pumpAndSettle();
    for (final digit in ['1', '2', '3', '4']) {
      await tester.tap(find.text(digit));
      await tester.pump();
    }
    expect(values, isEmpty);
    expect(
      find.text('Confirma tu PIN'),
      findsOneWidget,
    ); // PBKDF2 runs on real async time.
    for (final digit in ['1', '2', '3', '4']) {
      await tester.tap(find.text(digit));
      await tester.pump();
    }
    await tester.runAsync(() async {
      for (var i = 0; i < 100 && !store.unlocked; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 50));
      }
    });
    await tester.pumpAndSettle();
    expect(store.unlocked, isTrue);
    expect(values['pin.v1'], isNot(contains('1234')));
    await tester.runAsync(() async {
      expect(await store.pin.verify('9999'), isFalse);
      expect(await store.pin.verify('1234'), isTrue);
    });
    store.lock();
    await tester.pumpAndSettle();
    expect(find.text('Tu espacio privado'), findsOneWidget);
    for (final digit in ['1', '2', '3', '4']) {
      await tester.tap(find.text(digit));
      await tester.pump();
    }
    await tester.runAsync(() async {
      for (var i = 0; i < 300 && !store.unlocked; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 50));
      }
    });
    await tester.pumpAndSettle();
    expect(store.unlocked, isTrue);
    await tester.pumpWidget(const SizedBox());
  });
}
