/// Small, testable rules used while mapping local exam records to Supabase.
///
/// A local exam can outlive a deleted template in older databases because the
/// original SQLite schema did not enforce a foreign key from `exams.template_id`
/// to `exam_templates.id`. Sending such a stale id to Supabase causes SQLSTATE
/// 23503. Cloud payloads therefore keep the reference only when the template is
/// still present locally.
class ExamSyncPolicy {
  const ExamSyncPolicy._();

  static String? cloudTemplateId(
    String? templateId,
    Set<String> activeTemplateIds,
  ) {
    final normalized = templateId?.trim();
    if (normalized == null || normalized.isEmpty) return null;
    return activeTemplateIds.contains(normalized) ? normalized : null;
  }
}
