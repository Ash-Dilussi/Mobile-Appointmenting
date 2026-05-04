#!/usr/bin/env dart
/// End of Day - Mark all ongoing appointments as done
/// Usage: dart run scripts/end_day.dart

import 'package:hive/hive.dart';
import 'package:intl/intl.dart';

Future<void> main() async {
  final homeDir = r'd:\Projects\Vibe test\Mobile Appointmenting';
  final dbPath = '$homeDir\.dart_tool\hive';

  Hive.init(dbPath);
  final box = await Hive.openBox('Appointment');

  final now = DateTime.now();
  final todayStr = DateFormat('yyyy-MM-dd').format(now);

  int count = 0;
  for (var i = 0; i < box.length; i++) {
    final appt = box.getAt(i);
    if (appt.status == 'ongoing') {
      appt.status = 'done';
      appt.updatedAt = now;
      appt.synced = false;
      await box.put(appt.id, appt);
      count++;
    }
  }

  print('✅ End of day complete: $count appointments marked as done');
  await Hive.close();
}