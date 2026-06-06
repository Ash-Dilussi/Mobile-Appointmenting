import '../entities/auth_user.dart';
import 'permission.dart';

class RBACService {
  RBACService._();

  static const Map<UserRole, Set<Permission>> _permissions = {
    UserRole.owner: {
      Permission.viewDashboard,
      Permission.editInstitutionSettings,
      Permission.viewInstitutionDetails,
      Permission.manageOfficers,
      Permission.viewOfficerList,
      Permission.viewReports,
      Permission.exportReports,
      Permission.viewCalendar,
      Permission.createAppointment,
      Permission.editAppointment,
      Permission.deleteAppointment,
      Permission.viewCallLogs,
      Permission.manageCallLogs,
      Permission.viewCustomers,
      Permission.editCustomers,
      Permission.deleteCustomers,
      Permission.viewServices,
      Permission.manageServices,
    },
    UserRole.officer: {
      Permission.viewDashboard,
      Permission.viewInstitutionDetails,
      Permission.viewOfficerList,
      Permission.viewReports,
      Permission.viewCalendar,
      Permission.createAppointment,
      Permission.editAppointment,
      Permission.viewCallLogs,
      Permission.manageCallLogs,
      Permission.viewCustomers,
      Permission.editCustomers,
      Permission.viewServices,
    },
    UserRole.unknown: {},
  };

  static bool can(AuthUser user, Permission permission) {
    return _permissions[user.role]?.contains(permission) ?? false;
  }

  static bool canAll(AuthUser user, List<Permission> permissions) {
    return permissions.every((p) => can(user, p));
  }

  static bool canAny(AuthUser user, List<Permission> permissions) {
    return permissions.any((p) => can(user, p));
  }
}