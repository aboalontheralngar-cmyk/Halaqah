import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/student.dart';
import '../models/daily_record.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // Collections
  CollectionReference get _studentsRef => _db.collection('students');
  CollectionReference get _recordsRef => _db.collection('daily_records');

  // --- Student Operations ---

  Stream<List<Student>> getStudents() {
    return _studentsRef.orderBy('name').snapshots().map((snapshot) {
      return snapshot.docs.map((doc) => Student.fromFirestore(doc)).toList();
    });
  }

  Future<void> addStudent(Student student) async {
    await _studentsRef.doc(student.id).set(student.toFirestore());
  }

  Future<void> updateStudent(Student student) async {
    await _studentsRef.doc(student.id).update(student.toFirestore());
  }

  Future<void> deleteStudent(String id) async {
    await _studentsRef.doc(id).delete();
  }

  // --- Daily Record Operations ---

  Stream<List<DailyRecord>> getDailyRecords(DateTime date) {
    // Format date to compare only YYYY-MM-DD parts or use range
    // For simplicity with Timestamps, we might query by range of the day
    final startOfDay = DateTime(date.year, date.month, date.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));

    return _recordsRef
        .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
        .where('date', isLessThan: Timestamp.fromDate(endOfDay))
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) => DailyRecord.fromFirestore(doc)).toList();
    });
  }

  Future<void> saveDailyRecord(DailyRecord record) async {
    await _recordsRef.doc(record.id).set(record.toFirestore());
  }
}
