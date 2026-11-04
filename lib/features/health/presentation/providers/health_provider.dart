import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/health_connect.dart';

final healthAvailabilityProvider = FutureProvider<String>((ref) async {
  final source = HealthConnectDataSource();
  await source.status();
  return source.description;
});
