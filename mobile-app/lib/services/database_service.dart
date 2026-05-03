import 'package:cloud_firestore/cloud_firestore.dart';
import 'auth_service.dart';

class DatabaseService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final AuthService _authService = AuthService();

  Stream<DocumentSnapshot> getTodayPlan() {
    final studentId = _authService.getStudentId();
    final today = DateTime.now();
    final dateString = '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
    
    return _firestore
        .collection('students')
        .doc(studentId)
        .collection('daily_plans')
        .doc(dateString)
        .snapshots();
  }

  Stream<DocumentSnapshot> getStudentProgress() {
    final studentId = _authService.getStudentId();
    return _firestore
        .collection('students')
        .doc(studentId)
        .snapshots();
  }

  Future<void> toggleTask(String field) async {
    final studentId = _authService.getStudentId();
    final today = DateTime.now();
    final dateString = '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
    
    final docRef = _firestore
        .collection('students')
        .doc(studentId)
        .collection('daily_plans')
        .doc(dateString);

    final doc = await docRef.get();
    
    if (doc.exists) {
      await docRef.update({
        field: !doc.data()![field],
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }
  }

  Future<void> addNote(String note) async {
    final studentId = _authService.getStudentId();
    
    await _firestore.collection('notes').add({
      'studentId': studentId,
      'note': note,
      'timestamp': FieldValue.serverTimestamp(),
      'status': 'pending',
    });
  }

  // وظائف إضافية للمعلم
  Future<void> updateStudentStatus(String studentId, String status) async {
    await _firestore.collection('students').doc(studentId).update({
      'status': status,
      'lastUpdated': FieldValue.serverTimestamp(),
    });
  }

  Future<void> createDailyPlan(String studentId, Map<String, dynamic> plan) async {
    final today = DateTime.now();
    final dateString = '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
    
    await _firestore
        .collection('students')
        .doc(studentId)
        .collection('daily_plans')
        .doc(dateString)
        .set({
      ...plan,
      'date': dateString,
      'timestamp': FieldValue.serverTimestamp(),
    });
  }
}