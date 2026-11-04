import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:cryptography/cryptography.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:local_auth/local_auth.dart';

bool validPin(String pin) =>
    pin.length == 4 && RegExp(r'^[0-9]{4}$').hasMatch(pin);

Future<List<int>> _derivePin(
  ({String pin, List<int> salt, int rounds}) input,
) async {
  final key = await Pbkdf2(
    macAlgorithm: Hmac.sha256(),
    iterations: input.rounds,
    bits: 256,
  ).deriveKey(secretKey: SecretKey(utf8.encode(input.pin)), nonce: input.salt);
  return key.extractBytes();
}

class PinService {
  PinService({FlutterSecureStorage? storage})
    : storage = storage ?? const FlutterSecureStorage();
  final FlutterSecureStorage storage;
  static const iterations = 210000;
  Future<bool> exists() async => await storage.containsKey(key: 'pin.v1');
  Future<List<int>> derive(String pin, List<int> salt, int rounds) =>
      compute(_derivePin, (pin: pin, salt: salt, rounds: rounds));
  Future<void> set(String pin) async {
    if (!validPin(pin)) throw ArgumentError('PIN inválido');
    final random = Random.secure();
    final salt = List.generate(32, (_) => random.nextInt(256));
    final hash = await derive(pin, salt, iterations);
    await storage.write(
      key: 'pin.v1',
      value: jsonEncode({
        'salt': base64Encode(salt),
        'hash': base64Encode(hash),
        'iterations': iterations,
      }),
    );
  }

  Future<bool> verify(String pin) async {
    if (!validPin(pin)) return false;
    final raw = await storage.read(key: 'pin.v1');
    if (raw == null) return false;
    final m = jsonDecode(raw);
    final expected = base64Decode(m['hash']);
    final actual = await derive(pin, base64Decode(m['salt']), m['iterations']);
    var diff = expected.length ^ actual.length;
    for (var i = 0; i < actual.length && i < expected.length; i++) {
      diff |= actual[i] ^ expected[i];
    }
    return diff == 0;
  }

  Future<bool> biometricEnabled() async =>
      await storage.read(key: 'bio.enabled') != 'false';
  Future<void> setBiometric(bool value) =>
      storage.write(key: 'bio.enabled', value: '$value');
}

enum BioStatus {
  available,
  noHardware,
  noEnrollment,
  unavailable,
  cancelled,
  failed,
  success,
}

abstract class BiometricService {
  Future<BioStatus> availability();
  Future<BioStatus> authenticate();
  Future<void> cancel();
}

class DeviceBiometricService implements BiometricService {
  final auth = LocalAuthentication();
  static const channel = MethodChannel(
    'com.example.moodwave/legacy_fingerprint',
  );
  Future<bool> get legacy async =>
      Platform.isAndroid &&
      (await DeviceInfoPlugin().androidInfo).version.sdkInt <= 27;
  @override
  Future<BioStatus> availability() async {
    try {
      if (await legacy) {
        if (await channel.invokeMethod<bool>('isAvailable') != true) {
          return BioStatus.noHardware;
        }
        return await channel.invokeMethod<bool>('hasEnrolledFingerprints') ==
                true
            ? BioStatus.available
            : BioStatus.noEnrollment;
      }
      if (!await auth.canCheckBiometrics) return BioStatus.noHardware;
      return (await auth.getAvailableBiometrics()).isEmpty
          ? BioStatus.noEnrollment
          : BioStatus.available;
    } on LocalAuthException catch (error) {
      return _authError(error);
    } catch (_) {
      return BioStatus.unavailable;
    }
  }

  @override
  Future<BioStatus> authenticate() async {
    try {
      if (await legacy) {
        final value = await channel.invokeMethod<String>('authenticate');
        return BioStatus.values.firstWhere(
          (s) => s.name == value,
          orElse: () => BioStatus.unavailable,
        );
      }
      return await auth.authenticate(
            localizedReason: 'Desbloquear MoodWave',
            biometricOnly: true,
          )
          ? BioStatus.success
          : BioStatus.cancelled;
    } on LocalAuthException catch (error) {
      return _authError(error);
    } catch (_) {
      return BioStatus.unavailable;
    }
  }

  @override
  Future<void> cancel() async {
    try {
      if (await legacy) {
        await channel.invokeMethod<void>('cancel');
      } else {
        await auth.stopAuthentication();
      }
    } catch (_) {
      /* Cancellation remains safe if the platform was detached. */
    }
  }
}

BioStatus _authError(LocalAuthException error) => switch (error.code) {
  LocalAuthExceptionCode.userCanceled ||
  LocalAuthExceptionCode.systemCanceled ||
  LocalAuthExceptionCode.userRequestedFallback => BioStatus.cancelled,
  LocalAuthExceptionCode.noBiometricHardware => BioStatus.noHardware,
  LocalAuthExceptionCode.noBiometricsEnrolled ||
  LocalAuthExceptionCode.noCredentialsSet => BioStatus.noEnrollment,
  _ => BioStatus.unavailable,
};

String bioLabel(BioStatus s) => switch (s) {
  BioStatus.available => 'Biometría disponible',
  BioStatus.noHardware => 'Sin sensor biométrico',
  BioStatus.noEnrollment => 'Registra tu huella o rostro en el dispositivo',
  BioStatus.cancelled => 'Autenticación cancelada',
  BioStatus.failed => 'No se reconoció la huella. Intenta otra vez',
  BioStatus.success => 'Identidad confirmada',
  BioStatus.unavailable => 'Biometría temporalmente no disponible',
};
