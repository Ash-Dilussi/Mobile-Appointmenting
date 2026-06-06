import 'package:flutter/material.dart';

enum EventSource { local, google }

class CalendarBlock {
  const CalendarBlock({
    required this.id,
    required this.title,
    required this.start,
    required this.end,
    required this.source,
    required this.displayColor,
    this.googleEventId,
    this.subtitle,
  });

  final String id;
  final String title;
  final DateTime start;
  final DateTime end;
  final EventSource source;
  final Color displayColor;
  final String? googleEventId;
  final String? subtitle;

  Duration get duration => end.difference(start);

  bool overlapsWith(CalendarBlock other) =>
      start.isBefore(other.end) && end.isAfter(other.start);
}