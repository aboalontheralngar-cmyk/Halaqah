class ShareFileNameService {
  const ShareFileNameService._();

  static const String appName = 'حلقتي';

  static String safePart(String value) {
    final normalized = value
        .trim()
        .replaceAll(RegExp(r'[\\/:*?"<>|]'), '-')
        .replaceAll(RegExp(r'\s+'), '_');
    return normalized.isEmpty ? 'ملف' : normalized;
  }

  static String dated({
    required String label,
    required String extension,
    DateTime? date,
  }) {
    final value = date ?? DateTime.now();
    final stamp = '${value.year.toString().padLeft(4, '0')}-'
        '${value.month.toString().padLeft(2, '0')}-'
        '${value.day.toString().padLeft(2, '0')}';
    final ext = extension.replaceFirst(RegExp(r'^\.'), '');
    return '${appName}_${safePart(label)}_$stamp.$ext';
  }
}
