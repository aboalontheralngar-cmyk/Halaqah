import 'package:flutter/material.dart';
import 'package:intl/intl.dart' as intl;
import '../../models/notification_log.dart';
import '../../models/student.dart';
import '../../services/database_service.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final DatabaseService _db = DatabaseService();
  List<NotificationLog> _notifications = [];
  List<Student> _students = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      await _db.generateNotifications();
      final notifications = await _db.getNotifications();
      final students = await _db.getStudents();
      setState(() {
        _notifications = notifications;
        _students = students;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  String _getStudentName(String studentId) {
    final student = _students.firstWhere((s) => s.id == studentId, orElse: () => Student(name: 'طالب محذوف'));
    return student.name;
  }

  void _markAsRead(String id) async {
    await _db.markNotificationAsRead(id);
    _loadData();
  }

  void _markAllAsRead() async {
    await _db.markAllNotificationsAsRead();
    _loadData();
  }

  IconData _getNotificationIcon(String type) {
    switch (type) {
      case 'low_performance':
        return Icons.trending_down;
      case 'repeated_absence':
        return Icons.warning_amber_rounded;
      case 'plan_completed':
        return Icons.emoji_events;
      case 'dismissal_warning':
        return Icons.report_problem;
      case 'general':
      default:
        return Icons.info_outline;
    }
  }

  Color _getNotificationColor(String type) {
    switch (type) {
      case 'low_performance':
        return Colors.orange;
      case 'repeated_absence':
        return Colors.red;
      case 'plan_completed':
        return const Color(0xFF10B981);
      case 'dismissal_warning':
        return Colors.deepOrange;
      case 'general':
      default:
        return Colors.blue;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('سجل الإشعارات والتنبيهات'),
        actions: [
          if (_notifications.any((n) => !n.read))
            IconButton(
              icon: const Icon(Icons.mark_chat_read),
              tooltip: 'تحديد الكل كمقروء',
              onPressed: _markAllAsRead,
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadData,
              child: _notifications.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.notifications_off_outlined,
                            size: 64,
                            color: Colors.grey[400],
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'سجل الإشعارات فارغ حالياً',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 15,
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _notifications.length,
                      itemBuilder: (context, index) {
                        final notification = _notifications[index];
                        final color = _getNotificationColor(notification.type);
                        final icon = _getNotificationIcon(notification.type);
                        
                        return Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          elevation: notification.read ? 0 : 2,
                          color: notification.read
                              ? Theme.of(context).cardTheme.color
                              : color.withOpacity(0.05),
                          child: ListTile(
                            leading: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: color.withOpacity(0.15),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                icon,
                                color: color,
                                size: 24,
                              ),
                            ),
                            title: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    notification.title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontWeight: notification.read
                                          ? FontWeight.normal
                                          : FontWeight.bold,
                                    ),
                                  ),
                                ),
                                if (!notification.read) ...[
                                  const SizedBox(width: 8),
                                  Container(
                                    width: 8,
                                    height: 8,
                                    decoration: BoxDecoration(
                                      color: color,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            subtitle: Padding(
                              padding: const EdgeInsets.only(top: 6),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    notification.body,
                                    style: TextStyle(
                                      color: Theme.of(context)
                                          .textTheme
                                          .bodyMedium
                                          ?.color
                                          ?.withOpacity(0.8),
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          'الطالب: ${_getStudentName(notification.studentId)}',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Flexible(
                                        child: Text(
                                          intl.DateFormat('yyyy/MM/dd HH:mm')
                                              .format(notification.createdAt),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          textAlign: TextAlign.end,
                                          style: TextStyle(
                                            fontSize: 10,
                                            color: Colors.grey,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            onTap: () {
                              if (!notification.read) {
                                _markAsRead(notification.id);
                              }
                            },
                          ),
                        );
                      },
                    ),
            ),
    );
  }
}
