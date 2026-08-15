import 'package:flutter/material.dart';

import '../models/student.dart';
import '../utils/helpers.dart';
import 'database_service.dart';

class RecitationAttendanceGuard {
  const RecitationAttendanceGuard._();

  /// يمنع تحويل الغياب إلى حضور بصمت عند تسجيل تسميع فعلي.
  ///
  /// يعرض القرار للمعلم فقط إذا كان الطالب مسجلًا غائبًا في اليوم نفسه.
  static Future<bool> confirmPresentIfAbsent(
    BuildContext context, {
    required DatabaseService database,
    required Student student,
    DateTime? date,
  }) async {
    final target = date ?? DateTime.now();
    final existing = await database.getDailyRecord(student.id, target);
    if (existing?.attendance != 'absent') return true;
    if (!context.mounted) return false;

    final confirm = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: const Text('الطالب مسجل غائبًا'),
        content: Text(
          '${student.name} مسجل غائبًا في ${Helpers.formatPlanDate(target)}. لا يمكن اعتماد تسميع له مع إبقاء الغياب.\n\nهل تود تحضيره؟',
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
