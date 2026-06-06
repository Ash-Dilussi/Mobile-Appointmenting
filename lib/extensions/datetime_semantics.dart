import 'package:intl/intl.dart';

extension DateTimeSemantics on DateTime {
  String toFormattedDate() {
    return DateFormat('EEEE, d MMMM y').format(this);
  }

  String toTimeLabel() {
    return DateFormat('h:mm a').format(this);
  }
}