import 'package:flutter/material.dart';
import '../models/student.dart';
import '../app/design_tokens.dart';

class StudentCard extends StatelessWidget {
  final Student student;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final int? points;
  final String? subtitle;
  final Widget? trailing;
  final bool compact;

  const StudentCard({
    super.key,
    required this.student,
    this.onTap,
    this.onLongPress,
    this.points,
    this.subtitle,
    this.trailing,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    if (compact) {
      return _buildCompactCard(context);
    }
    return _buildFullCard(context);
  }

  Widget _buildCompactCard(BuildContext context) {
    return ListTile(
      onTap: onTap,
      onLongPress: onLongPress,
      leading: _buildAvatar(context, 20),
      title: Text(
        student.name,
        style: const TextStyle(fontWeight: FontWeight.w500),
      ),
      subtitle: subtitle != null ? Text(subtitle!) : null,
      trailing: trailing ?? _buildPointsBadge(context),
    );
  }

  Widget _buildFullCard(BuildContext context) {
    final statusColor = _getStatusColor(student.status);

    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        borderRadius: BorderRadius.circular(AppRadii.md),
        child: Padding(
          padding: AppSpacing.card,
          child: Row(
            children: [
              _buildAvatar(context, 28),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            student.name,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        _buildStatusChip(statusColor),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle ?? 'الحفظ: ${student.totalMemorized} آية | المقرر: ${student.planAmount} ${_getPlanLabel(student.planType)}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                    ),
                  ],
                ),
              ),
              if (trailing != null) ...[
                const SizedBox(width: 8),
                trailing!,
              ] else if (points != null) ...[
                const SizedBox(width: 8),
                _buildPointsBadge(context) ?? const SizedBox.shrink(),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAvatar(BuildContext context, double radius) {
    return CircleAvatar(
      radius: radius,
      backgroundColor: Theme.of(context).colorScheme.primaryContainer,
      child: student.photoPath != null
          ? ClipOval(
              child: Image.asset(
                student.photoPath!,
                fit: BoxFit.cover,
                width: radius * 2,
                height: radius * 2,
                errorBuilder: (_, __, ___) => _buildAvatarText(context),
              ),
            )
          : _buildAvatarText(context),
    );
  }

  Widget _buildAvatarText(BuildContext context) {
    return Text(
      student.name.isNotEmpty ? student.name[0] : '؟',
      style: TextStyle(
        color: Theme.of(context).colorScheme.onPrimaryContainer,
        fontWeight: FontWeight.bold,
      ),
    );
  }

  Widget _buildStatusChip(Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(AppRadii.pill),
      ),
      child: Text(
        _getStatusLabel(student.status),
        style: TextStyle(fontSize: 10, color: color),
      ),
    );
  }

  Widget? _buildPointsBadge(BuildContext context) {
    if (points == null) return null;
    final isPositive = points! >= 0;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: (isPositive ? Colors.green : Colors.red).withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        '${isPositive ? '+' : ''}$points',
        style: TextStyle(
          fontWeight: FontWeight.bold,
          color: isPositive ? Colors.green : Colors.red,
        ),
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'active':
        return Colors.green;
      case 'inactive':
        return Colors.orange;
      case 'suspended':
        return Colors.orange;
      case 'expelled':
        return Colors.red;
      case 'graduated':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }

  String _getStatusLabel(String status) {
    switch (status) {
      case 'active':
        return 'نشط';
      case 'inactive':
        return 'غير نشط';
      case 'suspended':
        return 'موقوف';
      case 'expelled':
        return 'مفصول';
      case 'graduated':
        return 'خاتم';
      default:
        return status;
    }
  }

  String _getPlanLabel(String planType) {
    switch (planType) {
      case 'ayahs':
        return 'آية';
      case 'lines':
        return 'سطر';
      case 'pages':
        return 'صفحة';
      default:
        return planType;
    }
  }
}
