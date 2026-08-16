import 'package:flutter/material.dart';

import '../models/student.dart';
import '../utils/helpers.dart';
import 'database_service.dart';

class RecitationAttendanceGuard {
  const RecitationAttendanceGuard._();

  /// يمنع وجود تسميع فعلي مع حالة حضور متعارضة.
  ///
  /// إذا كان الطالب غائبًا أو مستأذنًا في اليوم نفسه، يطلب من المعلم
  /// تأكيد تحويله إلى حاضر قبل اعتماد التسميع. هذا يمنع بقاء سجل تسميع
  /// مع غياب/استئذان في اليوم نفسه.
  static Future<bool> confirmPresentIfAbsent(
    BuildContext context, {
    required DatabaseService database,
    required Student student,
    DateTime? date,
  }) async {
    final target = date ?? DateTime.now();
    final existing = await database.getDailyRecord(student.id, target);
    final attendance = existing?.attendance;
    if (attendance != 'absent' && attendance != 'excused') return true;
    if (!context.mounted) return false;

    final confirm = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: Text(attendance == 'excused'
            ? 'الطالب مسجل مستأذنًا'
            : 'الطالب مسجل غائبًا'),
        content: Text(
          '${student.name} مسجل ${attendance == 'excused' ? 'مستأذنًا' : 'غائبًا'} في ${Helpers.formatPlanDate(target)}. لا يمكن اعتماد تسميع فعلي مع إبقاء هذه الحالة.\n\nهل تود تحويله إلى حاضر؟',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('إلغاء التسميع'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.pop(dialogContext, true),
            icon: const Icon(Icons.how_to_reg_outlined),
            label: const Text('نعم، تحضيره'),
          ),
        ],
      ),
    );
    if (confirm != true) return false;

    final now = DateTime.now();
    final isToday = target.year == now.year && target.month == now.month && target.day == now.day;
    await database.saveDailyRecord(
      existing!.copyWith(
        attendance: 'present',
        arrivalTime: existing.arrivalTime ?? (isToday ? now : null),
        clearAbsenceReason: true,
        clearAbsenceNote: true,
      ),
    );
    return true;
  }
}
