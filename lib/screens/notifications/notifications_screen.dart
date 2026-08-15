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
  String _filter = 'unread';
  String _query = '';

  List<NotificationLog> get _visibleNotifications {
    final normalized = _query.trim().toLowerCase();
    return _notifications.where((notification) {
      final matchesFilter = switch (_filter) {
        'unread' => !notification.read,
        'read' => notification.read,
        'attendance' => const [
            'repeated_absence',
            'dismissal_warning',
            'student_expelled',
          ]
            .contains(notification.type),
        'performance' => const ['low_performance', 'consecutive_no_recitation']
            .contains(notification.type),
        'plans' => const ['plan_completed', 'surah_completed']
            .contains(notification.type),
        _ => true,
      };
      if (!matchesFilter) return false;
      if (normalized.isEmpty) return true;
      final studentName = _getStudentName(notification.studentId).toLowerCase();
      return studentName.contains(normalized) ||
          notification.title.toLowerCase().contains(normalized) ||
          notification.body.toLowerCase().contains(normalized);
    }).toList();
  }

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
      case 'surah_completed':
        return Icons.auto_stories_outlined;
      case 'dismissal_warning':
        return Icons.report_problem;
      case 'consecutive_no_recitation':
        return Icons.menu_book_outlined;
      case 'student_expelled':
        return Icons.person_off_outlined;
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
      case 'surah_completed':
        return const Color(0xFF0D9488);
      case 'dismissal_warning':
        return Colors.deepOrange;
      case 'consecutive_no_recitation':
        return Colors.amber.shade800;
      case 'student_expelled':
        return Colors.red.shade800;
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
          : Column(
              children: [
                _buildFilters(),
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: _loadData,
                    child: _visibleNotifications.isEmpty
                        ? ListView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            children: [
                              SizedBox(height: MediaQuery.of(context).size.height * 0.2),
                              Icon(
                                Icons.notifications_off_outlined,
                                size: 64,
                                color: Theme.of(context).colorScheme.onSurfaceVariant,
                              ),
                              const SizedBox(height: 12),
                              Text(
                                _notifications.isEmpty
                                    ? 'سجل الإشعارات فارغ حاليًا'
                                    : 'لا توجد نتائج مطابقة للفلتر',
                                textAlign: TextAlign.center,
                                style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
                              ),
                            ],
                          )
                        : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _visibleNotifications.length,
                      itemBuilder: (context, index) {
                        final notification = _visibleNotifications[index];
                        final color = _getNotificationColor(notification.type);
                        final icon = _getNotificationIcon(notification.type);
                        
                        return Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          elevation: 0,
                          color: notification.read
                              ? Theme.of(context).cardTheme.color
                              : color.withValues(alpha: 0.05),
                          child: ListTile(
                            leading: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: color.withValues(alpha: 0.15),
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
                                          ?.withValues(alpha: 0.8),
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 4,
                                    alignment: WrapAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        'الطالب: ${_getStudentName(notification.studentId)}',
                                        style: const TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      Text(
                                        intl.DateFormat('yyyy/MM/dd HH:mm')
                                            .format(notification.createdAt),
                                        style: TextStyle(
                                          fontSize: 10,
                                          color: Theme.of(context).colorScheme.onSurfaceVariant,
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
                ),
              ],
            ),
    );
  }

  Widget _buildFilters() {
    final unread = _notifications.where((item) => !item.read).length;
    return Material(
      color: Theme.of(context).colorScheme.surface,
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    onChanged: (value) => setState(() => _query = value),
                    decoration: const InputDecoration(
                      hintText: 'ابحث باسم الطالب أو نص التنبيه',
                      prefixIcon: Icon(Icons.search),
                      isDense: true,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Chip(
                  avatar: const Icon(Icons.notifications_active_outlined, size: 17),
                  label: Text('$unread جديد'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 42,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  _filterChip('غير المقروء', 'unread'),
                  _filterChip('الكل', 'all'),
                  _filterChip('الحضور والغياب', 'attendance'),
                  _filterChip('الأداء', 'performance'),
                  _filterChip('الخطط', 'plans'),
                  _filterChip('المقروء', 'read'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _filterChip(String label, String value) => Padding(
        padding: const EdgeInsetsDirectional.only(end: 7),
        child: ChoiceChip(
          label: Text(label),
          selected: _filter == value,
          onSelected: (_) => setState(() => _filter = value),
        ),
      );
}
