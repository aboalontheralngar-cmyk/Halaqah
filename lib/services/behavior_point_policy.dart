class BehaviorPointPolicy {
  const BehaviorPointPolicy._();

  static const validTypes = {'positive', 'negative'};
  static const activeStudentStatuses = {'active', 'suspended'};

  static String? validate({
    required String type,
    required int points,
    required String reason,
    required String studentStatus,
  }) {
    if (!validTypes.contains(type)) return 'نوع النقاط غير صالح';
    if (reason.trim().isEmpty) return 'سبب النقاط مطلوب';
    if (type == 'positive' && points <= 0) {
      return 'النقاط الإيجابية يجب أن تكون أكبر من صفر';
    }
    if (type == 'negative' && points >= 0) {
      return 'النقاط السلبية يجب أن تكون أقل من صفر';
    }
    if (!activeStudentStatuses.contains(studentStatus)) {
      return 'لا يمكن إضافة نقاط لطالب موجود في الأرشيف';
    }
    return null;
  }
}
