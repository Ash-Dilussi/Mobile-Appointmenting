import 'package:flutter/material.dart';
import 'package:googleapis/calendar/v3.dart' as gcal;
import '../models/calendar_block.dart';
import 'google_auth_service.dart';

class GoogleCalendarService {
  GoogleCalendarService(this._authService);

  final GoogleAuthService _authService;
  static const _calendarId = 'primary';

  Future<gcal.CalendarApi> _api() async {
    final client = await _authService.authenticatedClient;
    if (client == null) {
      throw Exception('GoogleCalendarService: user not authenticated');
    }
    return gcal.CalendarApi(client);
  }

  Future<String> createEvent({
    required String title,
    required DateTime start,
    required DateTime end,
    String? description,
  }) async {
    final api = await _api();
    final event = gcal.Event()
      ..summary = title
      ..description = description
      ..start = (gcal.EventDateTime()
        ..dateTime = start.toUtc()
        ..timeZone = 'UTC')
      ..end = (gcal.EventDateTime()
        ..dateTime = end.toUtc()
        ..timeZone = 'UTC');

    final created = await _withRetry(() => api.events.insert(event, _calendarId));
    if (created.id == null) {
      throw Exception('Google Calendar returned event with null ID');
    }
    return created.id!;
  }

  Future<void> updateEvent({
    required String eventId,
    required String title,
    required DateTime start,
    required DateTime end,
    String? description,
  }) async {
    final api = await _api();
    final event = gcal.Event()
      ..summary = title
      ..description = description
      ..start = (gcal.EventDateTime()
        ..dateTime = start.toUtc()
        ..timeZone = 'UTC')
      ..end = (gcal.EventDateTime()
        ..dateTime = end.toUtc()
        ..timeZone = 'UTC');

    await _withRetry(() => api.events.update(event, _calendarId, eventId));
  }

  Future<void> deleteEvent(String eventId) async {
    final api = await _api();
    try {
      await _withRetry(() => api.events.delete(_calendarId, eventId));
    } on gcal.DetailedApiRequestError catch (e) {
      if (e.status != 404) rethrow;
    }
  }

  Future<List<CalendarBlock>> fetchExternalEvents(DateTime from, DateTime to) async {
    final api = await _api();
    final result = await _withRetry(() => api.events.list(
      _calendarId,
      timeMin: from.toUtc(),
      timeMax: to.toUtc(),
      singleEvents: true,
      orderBy: 'startTime',
    ));

    return (result.items ?? [])
        .where((e) => e.start?.dateTime != null && e.end?.dateTime != null)
        .map((e) => CalendarBlock(
          id: e.id ?? '',
          title: e.summary ?? '(No title)',
          start: e.start!.dateTime!.toLocal(),
          end: e.end!.dateTime!.toLocal(),
          source: EventSource.google,
          displayColor: const Color(0xFFEA4335),
          googleEventId: e.id,
          subtitle: e.organizer?.displayName,
        ))
        .toList();
  }

  Future<T> _withRetry<T>(Future<T> Function() fn) async {
    const delays = [
      Duration(seconds: 1),
      Duration(seconds: 2),
      Duration(seconds: 4),
    ];
    for (var i = 0; i <= delays.length; i++) {
      try {
        return await fn();
      } on gcal.DetailedApiRequestError catch (e) {
        if ((e.status == 429 || e.status == 503) && i < delays.length) {
          await Future.delayed(delays[i]);
        } else {
          rethrow;
        }
      }
    }
    throw StateError('Unreachable');
  }
}