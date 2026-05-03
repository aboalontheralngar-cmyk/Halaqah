import 'package:flutter/material.dart';

class AttendanceChip extends StatelessWidget {
  final String status;
  final Function(String)? onStatusChanged;
  final bool interactive;
  final bool showLabel;

  const AttendanceChip({
    super.key,
    required this.status,
    this.onStatusChanged,
    this.interactive = true,
    this.showLabel = true,
  });

  static const Map<String, AttendanceInfo> attendanceInfo = {
    'present': AttendanceInfo('حاضر', Icons.check_circle, Colors.green),
    'late': AttendanceInfo('متأخر', Icons.schedule, Colors.orange),
    'absent': AttendanceInfo('غائب', Icons.cancel, Colors.red),
    'vacation': AttendanceInfo('إجازة', Icons.beach_access, Colors.blue),
    '': AttendanceInfo('غير محدد', Icons.help_outline, Colors.grey),
  };

  @override
  Widget build(BuildContext context) {
    final info = attendanceInfo[status] ?? attendanceInfo['']!;

    if (interactive && onStatusChanged != null) {
      return PopupMenuButton<String>(
        onSelected: onStatusChanged,
        child: _buildChip(info),
        itemBuilder: (context) => [
          _buildMenuItem('present', attendanceInfo['present']!),
          _buildMenuItem('late', attendanceInfo['late']!),
          _buildMenuItem('absent', attendanceInfo['absent']!),
        ],
      );
    }

    return _buildChip(info);
  }

  Widget _buildChip(AttendanceInfo info) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: info.color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: info.color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(info.icon, size: 16, color: info.color),
          if (showLabel) ...[
            const SizedBox(width: 6),
            Text(
              info.label,
              style: TextStyle(
                color: info.color,
                fontWeight: FontWeight.w500,
                fontSize: 12,
              ),
            ),
          ],
        ],
      ),
    );
  }

  PopupMenuItem<String> _buildMenuItem(String value, AttendanceInfo info) {
    return PopupMenuItem<String>(
      value: value,
      child: Row(
        children: [
          Icon(info.icon, color: info.color, size: 20),
          const SizedBox(width: 12),
          Text(info.label),
        ],
      ),
    );
  }
}

class AttendanceInfo {
  final String label;
  final IconData icon;
  final Color color;

  const AttendanceInfo(this.label, this.icon, this.color);
}

class AttendanceSelector extends StatelessWidget {
  final String selectedStatus;
  final Function(String) onStatusSelected;

  const AttendanceSelector({
    super.key,
    required this.selectedStatus,
    required this.onStatusSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: ['present', 'late', 'absent'].map((status) {
        final info = AttendanceChip.attendanceInfo[status]!;
        final isSelected = status == selectedStatus;
        return InkWell(
          onTap: () => onStatusSelected(status),
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: isSelected ? info.color : info.color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: info.color,
                width: isSelected ? 2 : 1,
              ),
            ),
            child: Column(
              children: [
                Icon(
                  info.icon,
                  color: isSelected ? Colors.white : info.color,
                  size: 24,
                ),
                const SizedBox(height: 4),
                Text(
                  info.label,
                  style: TextStyle(
                    color: isSelected ? Colors.white : info.color,
                    fontWeight: FontWeight.w500,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}

class AttendanceIcon extends StatelessWidget {
  final String status;
  final double size;

  const AttendanceIcon({
    super.key,
    required this.status,
    this.size = 24,
  });

  @override
  Widget build(BuildContext context) {
    final info = AttendanceChip.attendanceInfo[status] ?? AttendanceChip.attendanceInfo['']!;
    return Icon(info.icon, color: info.color, size: size);
  }
}
