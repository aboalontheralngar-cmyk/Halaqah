import 'package:firebase_auth/firebase_auth.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Stream<User?> get authStateChanges => _auth.authStateChanges();
  User? get currentUser => _auth.currentUser;

  Future<void> signInWithPhone(String phoneNumber) async {
    try {
      // تسجيل دخول مبسط - يمكن تحسينه لاحقاً برمز التحقق
      await _auth.signInAnonymously();
    } catch (e) {
      print('Error signing in: $e');
      throw e;
    }
  }

  Future<void> signOut() async {
    await _auth.signOut();
  }

  String getStudentId() {
    return currentUser?.uid ?? '';
  }
}