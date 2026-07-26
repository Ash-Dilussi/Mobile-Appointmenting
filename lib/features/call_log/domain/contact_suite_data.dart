import '../../../../core/database/collections/appointment.dart';
import '../../../../core/database/collections/customer.dart';

/// Plain Dart class (not Hive) for Contact Suite View data
class ContactSuiteData {
  final Customer customer;
  final List<Appointment> upcomingAppointments; // soonest first
  final List<Appointment> pastAppointments; // most recent first

  ContactSuiteData({
    required this.customer,
    required this.upcomingAppointments,
    required this.pastAppointments,
  });
}
