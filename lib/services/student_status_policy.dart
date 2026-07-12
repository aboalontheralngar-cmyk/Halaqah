class StudentStatusPolicy {
  const StudentStatusPolicy._();

  static const validStatuses = {
    'active',
    'suspended',
    'expelled',
    'graduated',
    'inactive',
  };
  static const operationalStatuses = {'active', 'suspended'};
  static const archivedStatuses = {'expelled', 'graduated', 'inactive'};

  static bool isArchived(String status) => archivedStatuses.contains(status);

  static String? validateTransition({
    required String previousStatus,
    required String newStatus,
    required String reason,
  }) {
    if (!validStatuses.contains(previousStatus) ||
        !validStatuses.contains(newStatus)) {
      return 'حالة الطالب غير صالحة';
    }
    if (previousStatus == newStatus) return 'حالة الطالب لم تتغير';
    if (reason.trim().isEmpty) return 'سبب تغيير الحالة مطلوب';
    return null;
  }
}
