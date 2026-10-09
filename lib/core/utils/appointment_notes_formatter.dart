import '../database/collections/appointment_note.dart';

/// Formats structured appointment notes for plain-text integrations.
///
/// Each note stays visually distinct in destinations such as Google Calendar.
/// A title-only note remains valid and does not receive a trailing separator.
String? formatAppointmentNotesForCalendar(
  Iterable<AppointmentNote> notes,
) {
  final lines = notes.map((note) {
    final title = note.title.trim();
    final description = note.description?.trim();

    if (description == null || description.isEmpty) {
      return title;
    }
    return '$title: $description';
  }).where((line) => line.isNotEmpty);

  final description = lines.join('\n');
  return description.isEmpty ? null : description;
}
