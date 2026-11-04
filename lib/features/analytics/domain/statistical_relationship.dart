enum DifferenceSize { small, moderate, relevant }

class StatisticalRelationshipService {
  DifferenceSize classify(double difference) => difference.abs() < .30
      ? DifferenceSize.small
      : difference.abs() < .70
      ? DifferenceSize.moderate
      : DifferenceSize.relevant;
  String label(double difference) => switch (classify(difference)) {
    DifferenceSize.small => 'Pequeña',
    DifferenceSize.moderate => 'Moderada',
    DifferenceSize.relevant => 'Relevante en tus datos',
  };
  bool sufficient(int totalDays, int observations) =>
      totalDays >= 14 && observations >= 5;
}
