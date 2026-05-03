import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/auth_service.dart';
import '../services/database_service.dart';
import '../widgets/task_card.dart';
import '../widgets/progress_card.dart';

class HomeScreen extends StatefulWidget {
  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('حلقتي القرآنية'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(Icons.exit_to_app),
            onPressed: () => AuthService().signOut(),
          ),
        ],
      ),
      body: _selectedIndex == 0 ? _buildDailyTasks() : _buildProgress(),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) => setState(() => _selectedIndex = index),
        items: [
          BottomNavigationBarItem(
            icon: Icon(Icons.today),
            label: 'مهام اليوم',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.analytics),
            label: 'تقدمي',
          ),
        ],
      ),
    );
  }

  Widget _buildDailyTasks() {
    return StreamBuilder<DocumentSnapshot>(
      stream: DatabaseService().getTodayPlan(),
      builder: (context, snapshot) {
        if (snapshot.hasError) return Center(child: Text('حدث خطأ'));
        if (!snapshot.hasData || !snapshot.data!.exists) {
          return Center(child: Text('لا توجد مهام لهذا اليوم'));
        }

        final data = snapshot.data!.data() as Map<String, dynamic>?;
        if (data == null) return Center(child: Text('لا توجد بيانات'));

        return ListView(
          padding: EdgeInsets.all(16),
          children: [
            _buildWelcomeCard(),
            SizedBox(height: 16),
            TaskCard(
              title: 'حفظ جديد',
              verses: data['newMemorization'] ?? '0',
              surah: data['surah'] ?? '',
              isCompleted: data['memorizationCompleted'] ?? false,
              onTap: () => _toggleTask('memorizationCompleted'),
            ),
            SizedBox(height: 12),
            TaskCard(
              title: 'مراجعة',
              verses: data['revision'] ?? '0',
              surah: data['revisionSurah'] ?? '',
              isCompleted: data['revisionCompleted'] ?? false,
              onTap: () => _toggleTask('revisionCompleted'),
            ),
            SizedBox(height: 12),
            _buildQuickNote(),
          ],
        );
      },
    );
  }

  Widget _buildProgress() {
    return StreamBuilder<DocumentSnapshot>(
      stream: DatabaseService().getStudentProgress(),
      builder: (context, snapshot) {
        if (snapshot.hasError) return Center(child: Text('حدث خطأ'));
        if (!snapshot.hasData || !snapshot.data!.exists) {
          return Center(child: Text('لا توجد بيانات'));
        }

        final data = snapshot.data!.data() as Map<String, dynamic>?;
        if (data == null) return Center(child: Text('لا توجد بيانات'));

        return SingleChildScrollView(
          padding: EdgeInsets.all(16),
          child: Column(
            children: [
              ProgressCard(
                title: 'إجمالي الحفظ',
                value: '${data['totalMemorized'] ?? 0}',
                icon: Icons.book,
                color: Colors.green,
              ),
              SizedBox(height: 16),
              ProgressCard(
                title: 'نسبة الحضور',
                value: '${data['attendanceRate'] ?? 0}%',
                icon: Icons.calendar_today,
                color: Colors.blue,
              ),
              SizedBox(height: 16),
              ProgressCard(
                title: 'عدد المراجعات',
                value: '${data['totalRevisions'] ?? 0}',
                icon: Icons.repeat,
                color: Colors.orange,
              ),
              SizedBox(height: 16),
              _buildWeeklyProgress(),
            ],
          ),
        );
      },
    );
  }

  Widget _buildWelcomeCard() {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Container(
        padding: EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.teal.shade50, Colors.teal.shade100],
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'السلام عليكم',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.teal[800],
              ),
            ),
            SizedBox(height: 4),
            Text(
              'لديك ${DateTime.now().weekday == DateTime.friday || DateTime.now().weekday == DateTime.saturday ? 'مهام نهاية الأسبوع' : 'مهام اليوم'}',
              style: TextStyle(
                fontSize: 16,
                color: Colors.teal[600],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickNote() {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        leading: Icon(Icons.note_add, color: Colors.grey[600]),
        title: Text('ملاحظة سريعة'),
        subtitle: Text('أضف ملاحظة أو سؤال للمعلم'),
        trailing: Icon(Icons.arrow_forward_ios, size: 16),
        onTap: () => _showQuickNoteDialog(),
      ),
    );
  }

  Widget _buildWeeklyProgress() {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'تقدم هذا الأسبوع',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 12),
            LinearProgressIndicator(
              value: 0.7, // يتم تحديثها من قاعدة البيانات
              backgroundColor: Colors.grey[200],
              valueColor: AlwaysStoppedAnimation<Color>(Colors.teal),
            ),
            SizedBox(height: 4),
            Text(
              '7 من 10 أيام',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _toggleTask(String field) async {
    try {
      await DatabaseService().toggleTask(field);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('حدث خطأ أثناء التحديث')),
      );
    }
  }

  Future<void> _showQuickNoteDialog() async {
    final controller = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('ملاحظة للمعلم'),
        content: TextField(
          controller: controller,
          maxLines: 3,
          decoration: InputDecoration(
            hintText: 'اكتب ملاحظتك هنا...',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (controller.text.trim().isNotEmpty) {
                await DatabaseService().addNote(controller.text.trim());
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('تم إرسال الملاحظة')),
                );
              }
            },
            child: Text('إرسال'),
          ),
        ],
      ),
    );
  }
}