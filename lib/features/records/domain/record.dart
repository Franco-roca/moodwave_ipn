import 'dart:convert';

DateTime day(DateTime d) {
  final l = d.toLocal();
  return DateTime(l.year, l.month, l.day);
}

String dateKey(DateTime d) {
  final l = day(d);
  return '${l.year.toString().padLeft(4, '0')}-${l.month.toString().padLeft(2, '0')}-${l.day.toString().padLeft(2, '0')}';
}

DateTime shiftDay(DateTime d, int n) => DateTime(d.year, d.month, d.day + n);

enum Mood {
  angry('Enojado', '😡', 0xffb3261e),
  sad('Triste', '😢', 0xff2863a2),
  down('Desanimado', '😞', 0xff7953a8),
  worried('Preocupado', '😕', 0xffa95116),
  neutral('Neutral', '😐', 0xff626974),
  good('Bien', '🙂', 0xff28734b),
  happy('Feliz', '😄', 0xff946600),
  excellent('Excelente', '🤩', 0xff007d79);

  const Mood(this.name, this.emoji, this.hex);
  final String name, emoji;
  final int hex;
  int get value => index + 1;
  String get accessible => '$name, $value de 8';
}

const defaultActivities = [
  'Trabajo',
  'Estudio',
  'Ejercicio',
  'Familia',
  'Amigos',
  'Entretenimiento',
  'Descanso',
  'Viaje',
  'Compras',
  'Tareas domésticas',
];

class Record {
  Record({
    this.id,
    required DateTime date,
    required this.mood,
    required this.energy,
    this.activities = const [],
    this.reflection = '',
    DateTime? updated,
    this.test = false,
  }) : date = day(date),
       updated = updated ?? DateTime.now();
  final int? id;
  final DateTime date, updated;
  final Mood mood;
  final int energy;
  final List<String> activities;
  final String reflection;
  final bool test;
  Map<String, Object?> toMap() => {
    'dateKey': dateKey(date),
    'fecha': date.millisecondsSinceEpoch,
    'estadoAnimo': mood.value,
    'nivelEnergia': energy,
    'actividades': jsonEncode(activities),
    'reflexion': reflection,
    'horaActualizacion': updated.millisecondsSinceEpoch,
    'isTest': test ? 1 : 0,
  };
  factory Record.fromMap(Map<String, Object?> m) => Record(
    id: m['id'] as int,
    date: DateTime.parse(m['dateKey'] as String),
    mood: Mood.values[(m['estadoAnimo'] as int) - 1],
    energy: m['nivelEnergia'] as int,
    activities: List<String>.from(jsonDecode(m['actividades'] as String)),
    reflection: m['reflexion'] as String,
    updated: DateTime.fromMillisecondsSinceEpoch(m['horaActualizacion'] as int),
    test: m['isTest'] == 1,
  );
}
