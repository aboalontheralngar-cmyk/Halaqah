import '../models/student.dart';
import '../utils/quran_data.dart';

/// مصدر موحد لقرارات مسار التعلم التي تعتمد عليها الخطط وشاشات التسميع.
///
/// بعض البيانات القديمة تميّز الخاتم بإجمالي المحفوظ، وبعضها بالحالة
/// `graduated`. الجمع بينهما يمنع ظهور مقرر حفظ جديد لخاتم القرآن مهما كان
/// مصدر السجل.
class StudentLearningPolicy {
  const StudentLearningPolicy._();

  static bool hasCompletedQuran(Student student) =>
      student.status == 'graduated' ||
      student.totalMemorized >= QuranData.totalAyahs;

  static bool canReceiveNewMemorization(Student student) =>
      !hasCompletedQuran(student);

  static bool canReceiveRevision(Student student) =>
      student.status == 'active' || hasCompletedQuran(student);

  /// التلقين مرحلة اختيارية صريحة، ولا يظهر فيها إلا الطالب المحدد لها.
  static bool canReceiveTalaqqin(Student student) =>
      student.status == 'active' &&
      student.talaqqinEnabled &&
      !hasCompletedQuran(student);
}
