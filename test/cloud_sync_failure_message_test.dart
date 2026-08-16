import 'package:flutter_test/flutter_test.dart';
import 'package:halaqah_teacher/services/supabase_service.dart';

void main() {
  test('transient client errors never expose the Supabase URL to the user', () {
    final message = SupabaseService.instance.describeSyncFailure(
      Exception(
        'ClientException: Software caused connection abort, '
        'uri=https://example.supabase.co/rest/v1/rpc/set_study_suspension',
      ),
    );

    expect(message, contains('بيانات الجهاز محفوظة محليًا'));
    expect(message, isNot(contains('https://')));
    expect(message, isNot(contains('ClientException')));
  });

  test('known preflight failure is shown as a concise actionable message', () {
    const failure = CloudSyncUnavailableException(
      'انتهت مهلة الاتصال. تحقق من الشبكة ثم أعد المحاولة.',
    );

    expect(
      SupabaseService.instance.describeSyncFailure(failure),
      failure.message,
    );
  });
}
