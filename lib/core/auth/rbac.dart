/// Role-Based Access Control for multi-tenant app.
/// Defines user roles and their permissions within an institution.
enum Role {
  owner('Owner', 'Full administrative access to the institution'),
  officer('Officer', 'Operational access for day-to-day tasks');

  final String displayName;
  final String description;

  const Role(this.displayName, this.description);

  /// Check if this role has admin privileges (owner-only)
  bool get isAdmin => this == Role.owner;

  /// Check if this role has staff management permissions
  bool get canManageStaff => this == Role.owner;

  /// Check if this role can manage institution branding/settings
  bool get canManageInstitution => this == Role.owner;

  /// Check if this role can delete institutional data
  bool get canDeleteInstitutionData => this == Role.owner;

  /// Check if this role can invite new staff members
  bool get canInviteStaff => this == Role.owner;
}

/// Permission constants for feature-based access control.
class Permissions {
  Permissions._();

  // Calendar & Appointments - both roles can view and create
  static const String viewCalendar = 'view_calendar';
  static const String createAppointment = 'create_appointment';
  static const String editAppointment = 'edit_appointment';
  static const String deleteAppointment = 'delete_appointment';

  // Call Logs - both roles can view and manage
  static const String viewCallLogs = 'view_call_logs';
  static const String manageCallLogs = 'manage_call_logs';

  // Customers - both roles can view and edit
  static const String viewCustomers = 'view_customers';
  static const String editCustomers = 'edit_customers';
  static const String deleteCustomers = 'delete_customers';

  // Services - both roles can view, owner can manage
  static const String viewServices = 'view_services';
  static const String manageServices = 'manage_services';

  // Staff & Institution - owner only
  static const String manageStaff = 'manage_staff';
  static const String manageInstitution = 'manage_institution';
  static const String deleteInstitutionData = 'delete_institution_data';
}

/// Maps roles to their permissions.
class RolePermissions {
  RolePermissions._();

  static const Map<Role, Set<String>> permissions = {
    Role.owner: {
      // Full access
      Permissions.viewCalendar,
      Permissions.createAppointment,
      Permissions.editAppointment,
      Permissions.deleteAppointment,
      Permissions.viewCallLogs,
      Permissions.manageCallLogs,
      Permissions.viewCustomers,
      Permissions.editCustomers,
      Permissions.deleteCustomers,
      Permissions.viewServices,
      Permissions.manageServices,
      Permissions.manageStaff,
      Permissions.manageInstitution,
      Permissions.deleteInstitutionData,
    },
    Role.officer: {
      // Operational access only
      Permissions.viewCalendar,
      Permissions.createAppointment,
      Permissions.editAppointment,
      Permissions.viewCallLogs,
      Permissions.manageCallLogs,
      Permissions.viewCustomers,
      Permissions.editCustomers,
      Permissions.viewServices,
    },
  };

  /// Check if a role has a specific permission.
  static bool hasPermission(Role role, String permission) {
    return permissions[role]?.contains(permission) ?? false;
  }
}