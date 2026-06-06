import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/models/calendar_block.dart';
import '../../../../core/providers/auth_providers.dart';
import '../../../../core/providers/calendar_providers.dart';
import '../../../../core/database/hive_service.dart';

// Provider to access HiveService - override in main.dart
final hiveServiceProviderForCalendar = Provider<HiveService>((ref) {
  throw UnimplementedError('Must be overridden in ProviderScope');
});

// Cache for calendar blocks — keyed by normalized date (no time component)
final _calendarCache = <DateTime, List<CalendarBlock>>{};

final combinedCalendarProvider =
    FutureProvider.family<List<CalendarBlock>, DateTime>((ref, date) async {
  final normalizedDate = DateTime(date.year, date.month, date.day);

  // Return cached result if available
  if (_calendarCache.containsKey(normalizedDate)) {
    return _calendarCache[normalizedDate]!;
  }

  final dayStart = DateTime(date.year, date.month, date.day);
  final dayEnd = dayStart.add(const Duration(days: 1));

  // Local Hive appointments
  final hiveService = ref.read(hiveServiceProviderForCalendar);
  final allAppointments = hiveService.getAllAppointments();
  final localAppts = allAppointments.where((a) {
    return a.startTime.isAfter(dayStart.subtract(const Duration(seconds: 1))) &&
        a.startTime.isBefore(dayEnd);
  }).toList();

  final localBlocks = localAppts.map((a) {
    return CalendarBlock(
      id: a.id?.toString() ?? '',
      title: a.notes ?? 'Appointment',
      start: a.startTime,
      end: a.endTime,
      source: EventSource.local,
      displayColor: const Color(0xFF1A56DB),
      subtitle: null,
    );
  }).toList();

  // Google Calendar events (only if authenticated)
  List<CalendarBlock> googleBlocks = [];
  final authService = ref.read(googleAuthServiceProvider);
  if (authService.isSignedIn) {
    try {
      googleBlocks = await ref
          .read(googleCalendarServiceProvider)
          .fetchExternalEvents(dayStart, dayEnd);
    } catch (e) {
      // Silently degrade — local appointments always show
    }
  }

  // Merge and sort by start time
  final result = [...localBlocks, ...googleBlocks]
    ..sort((a, b) => a.start.compareTo(b.start));

  // Cache before returning
  _calendarCache[normalizedDate] = result;
  return result;
});