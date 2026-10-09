import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../auth/presentation/providers/auth_session_provider.dart';
import '../../home/presentation/providers/home_provider.dart';

enum AppCallLaunchResult {
  launched,
  sessionUnavailable,
  historyWriteFailed,
  dialerUnavailable,
}

extension AppCallLaunchResultMessage on AppCallLaunchResult {
  String? get failureMessage => switch (this) {
        AppCallLaunchResult.launched => null,
        AppCallLaunchResult.sessionUnavailable =>
          'Your session is unavailable. Sign in again before calling.',
        AppCallLaunchResult.historyWriteFailed =>
          'Could not save this call activity. Please try again.',
        AppCallLaunchResult.dialerUnavailable =>
          'Call activity was saved, but the phone dialer could not be opened.',
      };
}

typedef PhoneDialer = Future<bool> Function(Uri uri);
typedef AppCallLogWriter = Future<int?> Function({
  required int customerId,
  required String phoneNumber,
  required String institutionId,
  required String handledByUserId,
  DateTime? timestamp,
});

Future<bool> openExternalPhoneDialer(Uri uri) async {
  try {
    return await launchUrl(uri, mode: LaunchMode.externalApplication);
  } catch (_) {
    return false;
  }
}

class AppCallService {
  AppCallService({
    required AppCallLogWriter writeCallLog,
    required String? institutionId,
    required String? userId,
    PhoneDialer dialer = openExternalPhoneDialer,
  })  : _writeCallLog = writeCallLog,
        _institutionId = institutionId,
        _userId = userId,
        _dialer = dialer;

  final AppCallLogWriter _writeCallLog;
  final String? _institutionId;
  final String? _userId;
  final PhoneDialer _dialer;

  Future<AppCallLaunchResult> initiateCustomerCall({
    required int customerId,
    required String phoneNumber,
  }) async {
    final institutionId = _institutionId;
    final userId = _userId;
    if (institutionId == null ||
        institutionId.isEmpty ||
        userId == null ||
        userId.isEmpty) {
      return AppCallLaunchResult.sessionUnavailable;
    }

    final callLogId = await _writeCallLog(
      customerId: customerId,
      phoneNumber: phoneNumber,
      institutionId: institutionId,
      handledByUserId: userId,
    );
    if (callLogId == null) {
      return AppCallLaunchResult.historyWriteFailed;
    }

    final opened = await _dialer(Uri(scheme: 'tel', path: phoneNumber.trim()));
    return opened
        ? AppCallLaunchResult.launched
        : AppCallLaunchResult.dialerUnavailable;
  }
}

final appCallServiceProvider = Provider<AppCallService>((ref) {
  final session = ref.watch(authSessionProvider);
  final hiveService = ref.watch(homeHiveProvider);
  return AppCallService(
    writeCallLog: hiveService.insertAppInitiatedCallLog,
    institutionId: session?.institutionId,
    userId: session?.userId,
  );
});
