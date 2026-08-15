/// نقطة توسعة مدروسة لأكواد التفعيل المستقبلية.
///
/// لا تقيّد النسخة الحالية أي وظيفة، ولا تحتوي على مفتاح إصدار سري أو
/// خوارزمية قبول وهمية داخل التطبيق. عند اعتماد السياسة مستقبلًا يمكن
/// استبدالها بتحقق توقيع عام مع بقاء مفتاح الإصدار خارج التطبيق.
class ActivationPolicyService {
  static const bool activationRequired = false;
  static const String accessMode = 'unrestricted';
  static const String statusLabel =
      'غير مفعلة — جميع الميزات متاحة';

  static bool get isAccessAllowed => true;

  const ActivationPolicyService._();
}
