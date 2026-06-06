import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/presentation/screens/splash_screen.dart';
import '../../features/auth/presentation/screens/entrance_screen.dart';
import '../../features/auth/presentation/screens/login_screen.dart';
import '../../features/auth/presentation/screens/register_screen.dart';
import '../../features/auth/presentation/screens/forgot_password_screen.dart';
import '../../features/auth/presentation/screens/reset_password_screen.dart';
import '../../features/auth/presentation/screens/create_company_placeholder_screen.dart';
import '../../features/auth/presentation/providers/app_launch_provider.dart';
import '../../features/home/presentation/screens/home_screen.dart';
import '../../features/home/presentation/screens/main_shell.dart';
import '../../features/calendar/presentation/screens/calendar_screen.dart';
import '../../features/call_history/presentation/screens/call_history_screen.dart';
import '../../features/customers/presentation/screens/customers_screen.dart';
import '../../features/customers/presentation/screens/customer_profile_screen.dart';
import '../../features/customers/presentation/screens/add_customer_screen.dart';
import '../../features/settings/presentation/screens/settings_screen.dart';
import '../../features/settings/presentation/screens/profile_setup_screen.dart';
import '../../features/settings/presentation/screens/change_password_screen.dart';
import '../../features/services/presentation/screens/service_management_screen.dart';
import '../../features/services/presentation/screens/add_service_screen.dart';
import '../../features/services/presentation/screens/service_detail_screen.dart';
import '../../features/services/presentation/screens/station_management_screen.dart';
import '../../features/services/presentation/screens/add_station_screen.dart';
import '../../features/services/presentation/screens/station_detail_screen.dart';
import '../../features/settings/presentation/screens/staff_management_screen.dart';
import '../../features/settings/presentation/screens/edit_company_screen.dart';
import '../../features/settings/presentation/screens/operator_profile_screen.dart';
import '../../features/settings/presentation/screens/leave_requests_screen.dart';
import '../../features/settings/presentation/screens/create_company_screen.dart';
import '../../features/booking/presentation/screens/booking_screen.dart';
import '../../features/booking/presentation/screens/booking_confirmation_screen.dart';
import '../../features/booking/presentation/screens/appointment_detail_screen.dart';
import '../../features/calendar/presentation/screens/full_calendar_screen.dart';

// Navigation shell key
final _shellNavigatorKey = GlobalKey<NavigatorState>();
final _rootNavigatorKey = GlobalKey<NavigatorState>();

// Helper function for safe int parsing
int? _parseId(String? value) => value != null ? int.tryParse(value) : null;

// Router provider
final routerProvider = Provider<GoRouter>((ref) {
  // Watch appLaunchProvider to trigger redirects when auth state changes
  ref.watch(appLaunchProvider);

  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: '/splash',
    debugLogDiagnostics: true,
    redirect: (context, state) {
      final loc = state.matchedLocation;

      // Mid-session sign-out redirect handled by auth state
      // The splash screen handles cold-start routing via AppLaunchState
      switch (loc) {
        case '/entrance':
        case '/splash':
          return null;
        default:
          return null;
      }
    },
    routes: [
      // Entrance screen route
      GoRoute(
        path: '/entrance',
        name: 'entrance',
        builder: (context, state) {
          final launchState = state.extra as AppLaunchState;
          return EntranceScreen(launchState: launchState);
        },
      ),
      // Auth routes
      GoRoute(
        path: '/login',
        name: 'login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/register',
        name: 'register',
        builder: (context, state) => const RegisterScreen(),
      ),
      GoRoute(
        path: '/forgot-password',
        name: 'forgot-password',
        builder: (context, state) => const ForgotPasswordScreen(),
      ),
      GoRoute(
        path: '/reset-password',
        name: 'reset-password',
        builder: (context, state) {
          final email = state.uri.queryParameters['email'];
          return ResetPasswordScreen(resetEmail: email);
        },
      ),

      // Splash screen route
      GoRoute(
        path: '/splash',
        name: 'splash',
        builder: (context, state) => const SplashScreen(),
      ),

      // Create company route (for new users)
      GoRoute(
        path: '/create-company',
        name: 'create-company-placeholder',
        builder: (context, state) => const CreateCompanyPlaceholderScreen(),
      ),

      // Main app shell with bottom navigation
      ShellRoute(
        navigatorKey: _shellNavigatorKey,
        builder: (context, state, child) => MainShell(child: child),
        routes: [
          GoRoute(
            path: '/home',
            name: 'home',
            pageBuilder: (context, state) => CustomTransitionPage(
              key: state.pageKey,
              child: const HomeScreen(),
              transitionsBuilder: _fadeTransition,
            ),
          ),
          GoRoute(
            path: '/calendar',
            name: 'calendar',
            pageBuilder: (context, state) => CustomTransitionPage(
              key: state.pageKey,
              child: const CalendarScreen(),
              transitionsBuilder: _fadeTransition,
            ),
          ),
          GoRoute(
            path: '/call-history',
            name: 'call-history',
            pageBuilder: (context, state) => CustomTransitionPage(
              key: state.pageKey,
              child: const CallHistoryScreen(),
              transitionsBuilder: _fadeTransition,
            ),
          ),
          GoRoute(
            path: '/customers',
            name: 'customers',
            pageBuilder: (context, state) => CustomTransitionPage(
              key: state.pageKey,
              child: const CustomersScreen(),
              transitionsBuilder: _fadeTransition,
            ),
          ),
          GoRoute(
            path: '/settings',
            name: 'settings',
            pageBuilder: (context, state) => CustomTransitionPage(
              key: state.pageKey,
              child: const SettingsScreen(),
              transitionsBuilder: _fadeTransition,
            ),
          ),
        ],
      ),

      // Full screen routes (outside shell)
      GoRoute(
        path: '/customers/add',
        name: 'add-customer',
        builder: (context, state) {
          final phone = state.uri.queryParameters['phone'];
          return AddCustomerScreen(initialPhone: phone);
        },
      ),
      GoRoute(
        path: '/customers/edit/:id',
        name: 'edit-customer',
        builder: (context, state) {
          final id = _parseId(state.pathParameters['id']);
          if (id == null) return const SizedBox();
          return AddCustomerScreen(customerId: id);
        },
      ),
      GoRoute(
        path: '/customer/:id',
        name: 'customer-profile',
        builder: (context, state) {
          final id = _parseId(state.pathParameters['id']);
          if (id == null) return const SizedBox();
          return CustomerProfileScreen(customerId: id);
        },
      ),
      GoRoute(
        path: '/services',
        name: 'service-management',
        builder: (context, state) => const ServiceManagementScreen(),
      ),
      GoRoute(
        path: '/services/add',
        name: 'add-service',
        builder: (context, state) => const AddServiceScreen(),
      ),
      GoRoute(
        path: '/services/edit/:id',
        name: 'edit-service',
        builder: (context, state) {
          final id = _parseId(state.pathParameters['id']);
          if (id == null) return const SizedBox();
          return AddServiceScreen(serviceId: id);
        },
      ),
      GoRoute(
        path: '/services/detail/:id',
        name: 'service-detail',
        builder: (context, state) {
          final id = _parseId(state.pathParameters['id']);
          if (id == null) return const SizedBox();
          return ServiceDetailScreen(serviceId: id);
        },
      ),
      GoRoute(
        path: '/stations',
        name: 'station-management',
        builder: (context, state) => const StationManagementScreen(),
      ),
      GoRoute(
        path: '/stations/add',
        name: 'add-station',
        builder: (context, state) => const AddStationScreen(),
      ),
      GoRoute(
        path: '/stations/edit/:id',
        name: 'edit-station',
        builder: (context, state) {
          final id = _parseId(state.pathParameters['id']);
          if (id == null) return const SizedBox();
          return AddStationScreen(stationId: id);
        },
      ),
      GoRoute(
        path: '/stations/detail/:id',
        name: 'station-detail',
        builder: (context, state) {
          final id = _parseId(state.pathParameters['id']);
          if (id == null) return const SizedBox();
          return StationDetailScreen(stationId: id);
        },
      ),
      GoRoute(
        path: '/staff',
        name: 'staff-management',
        builder: (context, state) => const StaffManagementScreen(),
      ),
      GoRoute(
        path: '/company/edit',
        name: 'edit-company',
        builder: (context, state) => const EditCompanyScreen(),
      ),
      GoRoute(
        path: '/company/create',
        name: 'create-company',
        builder: (context, state) => const CreateCompanyScreen(),
      ),
      GoRoute(
        path: '/operator/:id',
        name: 'operator-profile',
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          return OperatorProfileScreen(operatorId: id);
        },
      ),
      GoRoute(
        path: '/leave-requests',
        name: 'leave-requests',
        builder: (context, state) => const LeaveRequestsScreen(),
      ),
      GoRoute(
        path: '/booking',
        name: 'booking',
        builder: (context, state) {
          final phone = state.uri.queryParameters['phone'];
          final callLogId = state.uri.queryParameters['callLogId'];
          final dateStr = state.uri.queryParameters['date'];
          return BookingScreen(
            prefilledPhone: phone,
            callLogId: callLogId != null ? int.parse(callLogId) : null,
            prefilledDate: dateStr != null ? DateTime.tryParse(dateStr) : null,
          );
        },
      ),
      GoRoute(
        path: '/booking/confirmation/:appointmentId',
        name: 'booking-confirmation',
        builder: (context, state) {
          final id = _parseId(state.pathParameters['appointmentId']);
          if (id == null) return const SizedBox();
          return BookingConfirmationScreen(appointmentId: id);
        },
      ),
      GoRoute(
        path: '/appointment/:id',
        name: 'appointment-detail',
        builder: (context, state) {
          final id = _parseId(state.pathParameters['id']);
          if (id == null) return const SizedBox();
          return AppointmentDetailScreen(appointmentId: id);
        },
      ),
      GoRoute(
        path: '/booking/edit/:id',
        name: 'booking-edit',
        builder: (context, state) {
          final id = _parseId(state.pathParameters['id']);
          if (id == null) return const SizedBox();
          return BookingScreen(appointmentId: id);
        },
      ),
      GoRoute(
        path: '/profile-setup',
        name: 'profile-setup',
        builder: (context, state) => const ProfileSetupScreen(),
      ),
      GoRoute(
        path: '/change-password',
        name: 'change-password',
        builder: (context, state) => const ChangePasswordScreen(),
      ),
      GoRoute(
        path: '/calendar/full',
        name: 'full-calendar',
        builder: (context, state) {
          final dateStr = state.uri.queryParameters['date'];
          final date = dateStr != null
              ? DateTime.tryParse(dateStr) ?? DateTime.now()
              : DateTime.now();
          return FullCalendarScreen(initialDate: date);
        },
      ),
    ],
    errorBuilder: (context, state) => Scaffold(
      body: Center(
        child: Text('Page not found: ${state.error}'),
      ),
    ),
  );
});

// Fade transition for smooth navigation
Widget _fadeTransition(
  BuildContext context,
  Animation<double> animation,
  Animation<double> secondaryAnimation,
  Widget child,
) {
  return FadeTransition(
    opacity: animation,
    child: child,
  );
}
