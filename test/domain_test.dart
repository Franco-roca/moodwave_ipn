import 'package:flutter_test/flutter_test.dart';
import 'package:moodwave/features/records/domain/record.dart';
import 'package:moodwave/features/statistics/domain/statistics.dart';
import 'package:moodwave/features/security/data/security.dart';

Record entry(DateTime date, {Mood mood = Mood.good, int energy = 5}) =>
    Record(date: date, mood: mood, energy: energy);
void main() {
  test('Normaliza a día local y genera clave estable', () {
    final d = DateTime(2026, 10, 30, 23, 59);
    expect(day(d), DateTime(2026, 10, 30));
    expect(dateKey(d), '2026-10-30');
  });
  test('Fechas UTC se interpretan como fechas locales', () {
    final d = DateTime.utc(2026, 1, 1, 2);
    final l = d.toLocal();
    expect(day(d), DateTime(l.year, l.month, l.day));
  });
  test('Promedios y emoción frecuente', () {
    final s = Statistics([
      entry(DateTime(2026, 1, 1), mood: Mood.sad, energy: 2),
      entry(DateTime(2026, 1, 2), energy: 8),
      entry(DateTime(2026, 1, 3), energy: 5),
    ]);
    expect(s.moodAverage, 14 / 3);
    expect(s.energyAverage, 5);
    expect(s.frequentMood, Mood.good);
  });
  test('Mejor día usa ánimo, energía y fecha más reciente', () {
    final a = entry(DateTime(2026, 1, 1), mood: Mood.excellent, energy: 8);
    final b = entry(DateTime(2026, 1, 2), mood: Mood.excellent, energy: 8);
    final c = entry(DateTime(2026, 1, 3), mood: Mood.happy, energy: 10);
    expect(Statistics([a, b, c]).best, b);
    expect(
      Statistics([
        a,
        entry(DateTime(2026, 1, 4), mood: Mood.excellent, energy: 9),
      ]).best!.energy,
      9,
    );
  });
  test('Rachas cruzan año y toleran hoy pendiente', () {
    final s = Statistics([
      entry(DateTime(2025, 12, 30)),
      entry(DateTime(2025, 12, 31)),
      entry(DateTime(2026, 1, 1)),
    ]);
    expect(s.bestStreak, 3);
    expect(s.currentStreak(DateTime(2026, 1, 2)), 3);
    expect(s.currentStreak(DateTime(2026, 1, 3)), 0);
  });
  test('Fechas únicas en mejor racha', () {
    final s = Statistics([
      entry(DateTime(2026, 1, 1)),
      entry(DateTime(2026, 1, 1)),
      entry(DateTime(2026, 1, 2)),
    ]);
    expect(s.bestStreak, 2);
  });
  test('Semana empieza lunes, excluye siguiente lunes', () {
    final list = [for (var i = 1; i <= 12; i++) entry(DateTime(2026, 1, i))];
    final p = Statistics.period(list, DateTime(2026, 1, 7), false);
    expect(p.length, 7);
    expect(p.first.date, DateTime(2026, 1, 5));
    expect(p.last.date, DateTime(2026, 1, 11));
  });
  test('Mes incluye todos sus días', () {
    final list = [for (var i = 1; i <= 32; i++) entry(DateTime(2026, 1, i))];
    expect(Statistics.period(list, DateTime(2026, 1, 20), true).length, 31);
  });
  test('Sin datos no divide entre cero', () {
    final s = Statistics([]);
    expect(s.moodAverage, 0);
    expect(s.energyAverage, 0);
    expect(s.best, isNull);
    expect(s.frequentMood, isNull);
    expect(s.bestStreak, 0);
  });
  test('PIN requiere exactamente cuatro dígitos', () {
    expect(validPin('0123'), isTrue);
    for (final p in ['123', '12345', 'abcd', '12 3', '1234\n']) {
      expect(validPin(p), isFalse);
    }
  });
  test('PBKDF2 usa salt y es determinista', () async {
    final pin = PinService();
    final a = await pin.derive('1234', [1, 2, 3], 1000);
    expect(a, await pin.derive('1234', [1, 2, 3], 1000));
    expect(a, isNot(await pin.derive('1234', [1, 2, 4], 1000)));
    expect(a.length, 32);
  });
}
