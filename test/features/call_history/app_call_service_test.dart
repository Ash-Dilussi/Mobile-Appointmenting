import 'package:bookly/features/call_history/application/app_call_service.dart';
import 'package:flutter_test/flutter_test.dart';

class _RecordingCallLogWriter {
  bool inserted = false;
  int? insertedCustomerId;
  String? insertedPhoneNumber;
  String? insertedInstitutionId;
  String? insertedUserId;
  int? result = 1;

  Future<int?> call({
    required int customerId,
    required String phoneNumber,
    required String institutionId,
    required String handledByUserId,
    DateTime? timestamp,
  }) async {
    inserted = true;
    insertedCustomerId = customerId;
    insertedPhoneNumber = phoneNumber;
    insertedInstitutionId = institutionId;
    insertedUserId = handledByUserId;
    return result;
  }
}

void main() {
  test('writes attributed history before opening the external dialer',
      () async {
    final hive = _RecordingCallLogWriter();
    Uri? launchedUri;
    final service = AppCallService(
      writeCallLog: hive.call,
      institutionId: 'test-inst',
      userId: 'test-user',
      dialer: (uri) async {
        expect(hive.inserted, isTrue);
        launchedUri = uri;
        return true;
      },
    );

    final result = await service.initiateCustomerCall(
      customerId: 42,
      phoneNumber: ' 0712345678 ',
    );

    expect(result, AppCallLaunchResult.launched);
    expect(hive.insertedCustomerId, 42);
    expect(hive.insertedPhoneNumber, ' 0712345678 ');
    expect(hive.insertedInstitutionId, 'test-inst');
    expect(hive.insertedUserId, 'test-user');
    expect(launchedUri, Uri(scheme: 'tel', path: '0712345678'));
  });

  test('does not open the dialer when history cannot be written', () async {
    final hive = _RecordingCallLogWriter()..result = null;
    var dialerOpened = false;
    final service = AppCallService(
      writeCallLog: hive.call,
      institutionId: 'test-inst',
      userId: 'test-user',
      dialer: (_) async {
        dialerOpened = true;
        return true;
      },
    );

    final result = await service.initiateCustomerCall(
      customerId: 42,
      phoneNumber: '0712345678',
    );

    expect(result, AppCallLaunchResult.historyWriteFailed);
    expect(dialerOpened, isFalse);
  });
}
