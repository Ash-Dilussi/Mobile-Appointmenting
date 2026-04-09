import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/presentation/screens/login_screen.dart';
import '../../features/auth/presentation/screens/register_screen.dart';
import '../../features/home/presentation/screens/home_screen.dart';
import '../../features/home/presentation/screens/main_shell.dart';
import '../../features/calendar/presentation/screens/calendar_screen.dart';
import '../../features/call_history/presentation/screens/call_history_screen.dart';
import '../../features/customers/presentation/screens/customers_screen.dart';
import '../../features/customers/presentation/screens/customer_profile_screen.dart';
import '../../features/settings/presentation/screens/settings_screen.dart';
import '../../features/services/presentation/screens/service_management_screen.dart';
import '../../features/services/presentation/screens/add_service_screen.dart';
import '../../features/booking/presentation/screens/booking_screen.dart';
import '../../features/booking/presentation/screens/booking_confirmation_screen.dart';
import '../../features/auth/presentation/providers/auth_provider.dart';

// Navigation shell key
final _shellNavigatorKey = GlobalKey<NavigatorState>();
final _rootNavigatorKey = GlobalKey<NavigatorState>();

// Router provider
final routerProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authStateProvider);

  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: '/login',
    debugLogDiagnostics: true,
    redirect: (context, state) {
      final isLoggedIn = authState.status == AuthStatus.authenticated;
      final isAuthRoute = state.matchedLocation == '/login' ||
          state.matchedLocation == '/register';

      if (!isLoggedIn && !isAuthRoute) {
        return '/login';
      }

      if (isLoggedIn && isAuthRoute) {
        return '/home';
      }

      return null;
    },
    routes: [
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
        path: '/customer/:id',
        name: 'customer-profile',
        builder: (context, state) {
          final id = int.parse(state.pathParameters['id']!);
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
          final id = int.parse(state.pathParameters['id']!);
          return AddServiceScreen(serviceId: id);
        },
      ),
      GoRoute(
        path: '/booking',
        name: 'booking',
        builder: (context, state) {
          final phone = state.uri.queryParameters['phone'];
          final callLogId = state.uri.queryParameters['callLogId'];
          return BookingScreen(
            prefilledPhone: phone,
            callLogId: callLogId != null ? int.parse(callLogId) : null,
          );
        },
      ),
      GoRoute(
        path: '/booking/confirmation/:appointmentId',
        name: 'booking-confirmation',
        builder: (context, state) {
          final id = int.parse(state.pathParameters['appointmentId']!);
          return BookingConfirmationScreen(appointmentId: id);
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
