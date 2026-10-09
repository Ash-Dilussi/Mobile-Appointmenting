import 'package:bookly/core/database/collections/appointment_note.dart';
import 'package:bookly/core/utils/appointment_notes_formatter.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('formats multiple structured notes for Google Calendar', () {
    final timestamp = DateTime(2026, 9, 6);
    final notes = [
      AppointmentNote(
        id: '1',
        title: 'Preparation',
        description: 'Arrive ten minutes early',
        createdAt: timestamp,
        updatedAt: timestamp,
      ),
      AppointmentNote(
        id: '2',
        title: 'Accessibility',
        createdAt: timestamp,
        updatedAt: timestamp,
      ),
    ];

    expect(
      formatAppointmentNotesForCalendar(notes),
      'Preparation: Arrive ten minutes early\nAccessibility',
    );
  });

  test('returns null when there are no notes', () {
    expect(formatAppointmentNotesForCalendar(const []), isNull);
  });
}
