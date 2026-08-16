import 'package:flutter_test/flutter_test.dart';
import 'package:halaqah_teacher/services/study_suspension_sync_plan.dart';

void main() {
  test('only changed suspension dates are sent to the cloud', () {
    final plan = StudySuspensionSyncPlan.create(
      local: const {
        '2026-08-10': 'سبب جديد',
        '2026-08-12': 'أعيدت إضافتها',
      },
      remote: const {
        '2026-08-10': 'سبب قديم',
        '2026-08-11': 'سحاب فقط',
      },
      pendingDeletedDates: const {
        '2026-08-11',
        '2026-08-12',
      },
    );

    expect(plan.datesToRemove, ['2026-08-11']);
    expect(plan.suspensionsToSet, {
      '2026-08-10': 'سبب جديد',
      '2026-08-12': 'أعيدت إضافتها',
    });
    expect(plan.mergedRemoteState, {
      '2026-08-10': 'سبب جديد',
      '2026-08-12': 'أعيدت إضافتها',
    });
  });

  test('unchanged historical suspensions produce no RPC work', () {
    final plan = StudySuspensionSyncPlan.create(
      local: const {
        '2026-08-10': 'إجازة عارضة',
        '2026-08-12': 'مطر شديد',
      },
      remote: const {
        '2026-08-10': 'إجازة عارضة',
        '2026-08-12': 'مطر شديد',
      },
      pendingDeletedDates: const {},
    );

    expect(plan.datesToRemove, isEmpty);
    expect(plan.suspensionsToSet, isEmpty);
    expect(plan.mergedRemoteState.length, 2);
  });
}
