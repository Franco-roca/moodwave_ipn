import '../../../core/refugio_art.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/state.dart';
import '../../../core/widgets.dart';
import '../data/security.dart';

class SecurityScreen extends ConsumerStatefulWidget {
  const SecurityScreen({super.key, this.changePin = false});
  final bool changePin;
  @override
  ConsumerState<SecurityScreen> createState() => _SecurityScreenState();
}

class _SecurityScreenState extends ConsumerState<SecurityScreen> {
  late final AppStore store;
  @override
  void initState() {
    super.initState();
    store = ref.read(storeProvider);
  }

  String entered = '', first = '', message = '';
  bool busy = false;
  int failures = 0;
  DateTime? retryAfter;
  Future<void> digit(String digit) async {
    if (busy || entered.length == 4) return;
    setState(() => entered += digit);
    if (entered.length != 4) return;
    final store = ref.read(storeProvider);
    final candidate = entered;
    final lockVersion = store.lockVersion;
    setState(() => busy = true);
    try {
      if (retryAfter != null && DateTime.now().isBefore(retryAfter!)) {
        setState(
          () => message = 'Espera un momento antes de volver a intentar.',
        );
        return;
      }
      if (widget.changePin || !store.hasPin) {
        if (first.isEmpty) {
          setState(() {
            first = candidate;
            message = 'Repite el nuevo PIN';
          });
          return;
        }
        if (first != candidate) {
          setState(() {
            first = '';
            message = 'Los PIN no coinciden. Vuelve a empezar.';
          });
          return;
        }
        await store.pin.set(candidate);
        store.pinConfigured();
        if (!mounted) return;
        if (store.lockVersion != lockVersion) return;
        if (widget.changePin) {
          context.pop();
        } else {
          store.unlock();
        }
      } else if (await store.pin.verify(candidate)) {
        if (!mounted || store.lockVersion != lockVersion) return;
        store.unlock();
      } else {
        if (!mounted || store.lockVersion != lockVersion) return;
        failures++;
        if (failures >= 5) {
          retryAfter = DateTime.now().add(const Duration(seconds: 30));
        }
        setState(
          () => message =
              'PIN incorrecto${failures >= 5 ? '. Espera 30 segundos' : ''}',
        );
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => message =
              'No se pudo verificar o guardar el PIN. Intenta nuevamente.',
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          busy = false;
          entered = '';
        });
      }
    }
  }

  Future<void> biometric() async {
    final store = ref.read(storeProvider);
    setState(() {
      busy = true;
      message = 'Coloca el dedo en el lector o sigue el diálogo del sistema';
    });
    store.authenticating = true;
    try {
      final available = await store.biometrics.availability();
      final result = available == BioStatus.available
          ? await store.biometrics.authenticate()
          : available;
      if (!mounted) return;
      if (result == BioStatus.success) {
        store.unlock();
      } else {
        setState(() => message = bioLabel(result));
      }
    } finally {
      store.authenticating = false;
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  void dispose() {
    store.biometrics.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final store = ref.read(storeProvider);
    final creating = widget.changePin || !store.hasPin;
    return Scaffold(
      appBar: widget.changePin
          ? AppBar(title: const Text('Cambiar PIN'))
          : null,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 360),
              child: Column(
                children: [
                  const WaveHeader(
                    'MoodWave',
                    'Un espacio que sigue tu ritmo.',
                  ),
                  const SizedBox(height: 24),
                  Text(
                    creating
                        ? (first.isEmpty ? 'Crea tu PIN' : 'Confirma tu PIN')
                        : 'Tu espacio privado',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Un momento para ti. Tus datos se quedan aquí.',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  if (store.startupError != null)
                    Text(store.startupError!)
                  else ...[
                    Semantics(
                      label: '${entered.length} de 4 dígitos',
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(
                          4,
                          (i) => Padding(
                            padding: const EdgeInsets.all(10),
                            child: RefugioIcon(
                              i < entered.length
                                  ? Icons.circle
                                  : Icons.circle_outlined,
                              size: 18,
                            ),
                          ),
                        ),
                      ),
                    ),
                    if (busy) const LinearProgressIndicator(),
                    Semantics(
                      liveRegion: true,
                      child: Text(message, textAlign: TextAlign.center),
                    ),
                    const SizedBox(height: 12),
                    GridView.count(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisCount: 3,
                      childAspectRatio: 1.5,
                      mainAxisSpacing: 8,
                      crossAxisSpacing: 8,
                      children: [
                        for (final n in [
                          '1',
                          '2',
                          '3',
                          '4',
                          '5',
                          '6',
                          '7',
                          '8',
                          '9',
                        ])
                          FilledButton.tonal(
                            onPressed: busy ? null : () => digit(n),
                            child: Text(
                              n,
                              style: const TextStyle(fontSize: 25),
                            ),
                          ),
                        IconButton(
                          tooltip: busy
                              ? 'Cancelar biometría'
                              : 'Usar biometría',
                          onPressed: !creating && store.bioEnabled
                              ? () => busy
                                    ? store.biometrics.cancel()
                                    : biometric()
                              : null,
                          icon: const RefugioIcon(Icons.fingerprint, size: 32),
                        ),
                        FilledButton.tonal(
                          onPressed: busy ? null : () => digit('0'),
                          child: const Text(
                            '0',
                            style: TextStyle(fontSize: 25),
                          ),
                        ),
                        IconButton(
                          tooltip: 'Borrar dígito',
                          onPressed: busy
                              ? null
                              : () => setState(
                                  () => entered = entered.isEmpty
                                      ? ''
                                      : entered.substring(
                                          0,
                                          entered.length - 1,
                                        ),
                                ),
                          icon: const RefugioIcon(Icons.backspace_outlined),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
